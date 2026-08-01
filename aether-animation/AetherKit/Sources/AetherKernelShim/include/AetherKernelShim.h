#ifndef ANIMA_CAD_SHIM_H
#define ANIMA_CAD_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ACFaceRange {
  uint32_t vertex_offset;
  uint32_t vertex_count;
  uint32_t index_offset;
  uint32_t index_count;
  float color[4];
  int32_t assembly_node;
  int32_t topology_index;
} ACFaceRange;

typedef struct ACEdgeRange {
  uint32_t point_offset;
  uint32_t point_count;
  int32_t assembly_node;
  int32_t topology_index;
} ACEdgeRange;

typedef struct ACAssemblyNode {
  char *name;
  int32_t parent_index;
  uint32_t first_face;
  uint32_t face_count;
  double transform[16];
} ACAssemblyNode;

typedef struct ACDocument {
  float *positions;
  float *normals;
  uint32_t *indices;
  ACFaceRange *faces;
  float *edge_points;
  ACEdgeRange *edges;
  ACAssemblyNode *nodes;
  uint32_t vertex_count;
  uint32_t index_count;
  uint32_t face_count;
  uint32_t edge_point_count;
  uint32_t edge_count;
  uint32_t node_count;
  double read_seconds;
  double transfer_seconds;
  double triangulation_seconds;
  double maximum_tolerance_m;
  char *error_message;
} ACDocument;

/// Reads STEP/STP with Open CASCADE STEPCAFControl_Reader. The returned
/// renderer-neutral geometry is in metres and retains XDE assembly labels,
/// face/body colors, B-Rep face identity, and exact feature-edge samples.
ACDocument aether_kernel_load_step(
    const char *path,
    double linear_deflection_m,
    double angular_deflection_radians);

/// Deterministic kernel fixture used by unit tests; never shown as operator data.
ACDocument aether_kernel_make_test_document(
    double linear_deflection_m,
    double angular_deflection_radians);

void aether_kernel_free_document(ACDocument document);
const char *aether_kernel_open_cascade_version(void);

#ifdef __cplusplus
}
#endif

#endif
