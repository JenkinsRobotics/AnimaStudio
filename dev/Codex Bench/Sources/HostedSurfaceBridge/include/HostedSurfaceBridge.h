#ifndef HOSTED_SURFACE_BRIDGE_H
#define HOSTED_SURFACE_BRIDGE_H

#include <IOSurface/IOSurface.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct GBHostedSurfaceReceiver GBHostedSurfaceReceiver;

GBHostedSurfaceReceiver *GBHostedSurfaceReceiverCreate(const char *service_name);
void GBHostedSurfaceReceiverDestroy(GBHostedSurfaceReceiver *receiver);

IOSurfaceRef GBHostedSurfaceReceiverCopyNext(
  GBHostedSurfaceReceiver *receiver,
  uint32_t timeout_milliseconds,
  uint32_t *width,
  uint32_t *height,
  uint32_t *sequence
) CF_RETURNS_RETAINED;

bool GBHostedSurfaceSend(
  const char *service_name,
  IOSurfaceRef surface,
  uint32_t width,
  uint32_t height,
  uint32_t sequence
);

#ifdef __cplusplus
}
#endif

#endif
