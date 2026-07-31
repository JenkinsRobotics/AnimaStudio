#include "HostedSurfaceBridge.h"

#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <stdlib.h>
#include <string.h>

struct GBHostedSurfaceReceiver {
  mach_port_t receive_port;
};

typedef struct {
  mach_msg_header_t header;
  mach_msg_body_t body;
  mach_msg_port_descriptor_t surface_port;
  uint32_t width;
  uint32_t height;
  uint32_t sequence;
} GBHostedSurfaceMessage;

typedef struct {
  GBHostedSurfaceMessage message;
  mach_msg_max_trailer_t trailer;
} GBHostedSurfaceReceiveBuffer;

GBHostedSurfaceReceiver *GBHostedSurfaceReceiverCreate(const char *service_name) {
  if (service_name == NULL || service_name[0] == '\0') return NULL;
  GBHostedSurfaceReceiver *receiver = calloc(1, sizeof(GBHostedSurfaceReceiver));
  if (receiver == NULL) return NULL;
  kern_return_t result = mach_port_allocate(
    mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &receiver->receive_port);
  if (result != KERN_SUCCESS) {
    free(receiver);
    return NULL;
  }
  result = mach_port_insert_right(
    mach_task_self(), receiver->receive_port, receiver->receive_port, MACH_MSG_TYPE_MAKE_SEND);
  if (result != KERN_SUCCESS
      || bootstrap_register(bootstrap_port, (char *)service_name, receiver->receive_port)
        != BOOTSTRAP_SUCCESS) {
    mach_port_destroy(mach_task_self(), receiver->receive_port);
    free(receiver);
    return NULL;
  }
  return receiver;
}

void GBHostedSurfaceReceiverDestroy(GBHostedSurfaceReceiver *receiver) {
  if (receiver == NULL) return;
  mach_port_destroy(mach_task_self(), receiver->receive_port);
  free(receiver);
}

IOSurfaceRef GBHostedSurfaceReceiverCopyNext(
  GBHostedSurfaceReceiver *receiver,
  uint32_t timeout_milliseconds,
  uint32_t *width,
  uint32_t *height,
  uint32_t *sequence
) {
  if (receiver == NULL) return NULL;
  GBHostedSurfaceReceiveBuffer buffer;
  memset(&buffer, 0, sizeof(buffer));
  kern_return_t result = mach_msg(
    &buffer.message.header,
    MACH_RCV_MSG | MACH_RCV_TIMEOUT,
    0,
    sizeof(buffer),
    receiver->receive_port,
    timeout_milliseconds,
    MACH_PORT_NULL);
  if (result != KERN_SUCCESS || buffer.message.body.msgh_descriptor_count != 1
      || buffer.message.surface_port.type != MACH_MSG_PORT_DESCRIPTOR) {
    return NULL;
  }
  IOSurfaceRef surface = IOSurfaceLookupFromMachPort(buffer.message.surface_port.name);
  mach_port_deallocate(mach_task_self(), buffer.message.surface_port.name);
  if (surface == NULL) return NULL;
  if (width != NULL) *width = buffer.message.width;
  if (height != NULL) *height = buffer.message.height;
  if (sequence != NULL) *sequence = buffer.message.sequence;
  return surface;
}

bool GBHostedSurfaceSend(
  const char *service_name,
  IOSurfaceRef surface,
  uint32_t width,
  uint32_t height,
  uint32_t sequence
) {
  if (service_name == NULL || surface == NULL) return false;
  mach_port_t destination = MACH_PORT_NULL;
  if (bootstrap_look_up(bootstrap_port, service_name, &destination) != BOOTSTRAP_SUCCESS) {
    return false;
  }
  mach_port_t surface_port = IOSurfaceCreateMachPort(surface);
  if (surface_port == MACH_PORT_NULL) {
    mach_port_deallocate(mach_task_self(), destination);
    return false;
  }

  GBHostedSurfaceMessage message;
  memset(&message, 0, sizeof(message));
  message.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0) | MACH_MSGH_BITS_COMPLEX;
  message.header.msgh_size = sizeof(message);
  message.header.msgh_remote_port = destination;
  message.header.msgh_local_port = MACH_PORT_NULL;
  message.header.msgh_id = 0x4742;
  message.body.msgh_descriptor_count = 1;
  message.surface_port.name = surface_port;
  message.surface_port.disposition = MACH_MSG_TYPE_MOVE_SEND;
  message.surface_port.type = MACH_MSG_PORT_DESCRIPTOR;
  message.width = width;
  message.height = height;
  message.sequence = sequence;

  kern_return_t result = mach_msg(
    &message.header, MACH_SEND_MSG | MACH_SEND_TIMEOUT, message.header.msgh_size, 0,
    MACH_PORT_NULL, 1000, MACH_PORT_NULL);
  mach_port_deallocate(mach_task_self(), destination);
  if (result != KERN_SUCCESS) mach_port_deallocate(mach_task_self(), surface_port);
  return result == KERN_SUCCESS;
}
