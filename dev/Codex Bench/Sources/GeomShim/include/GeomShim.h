#ifndef GEOM_BENCH_SHIM_H
#define GEOM_BENCH_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct GBFaceRange {
  uint32_t vertex_offset;
  uint32_t vertex_count;
  uint32_t index_offset;
  uint32_t index_count;
  float color[4];
  int32_t assembly_node;
  int32_t topology_index;
} GBFaceRange;

typedef struct GBEdgeRange {
  uint32_t point_offset;
  uint32_t point_count;
  int32_t assembly_node;
  int32_t topology_index;
} GBEdgeRange;

typedef struct GBAssemblyNode {
  char *name;
  int32_t parent_index;
  uint32_t first_face;
  uint32_t face_count;
  double transform[16];
} GBAssemblyNode;

typedef struct GBDocument {
  float *positions;
  float *normals;
  uint32_t *indices;
  GBFaceRange *faces;
  float *edge_points;
  GBEdgeRange *edges;
  GBAssemblyNode *nodes;
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
} GBDocument;

/// Loads STEP/STP through STEPCAFControl_Reader, preserving XDE assembly labels
/// and per-face/body colors. Geometry is emitted in metres as contiguous arrays.
GBDocument gb_load_step_document(
    const char *path,
    double linear_deflection_m,
    double angular_deflection_radians);

/// Kernel-built B-Rep fixture used by deterministic tests and the empty app.
GBDocument gb_make_demo_document(
    double linear_deflection_m,
    double angular_deflection_radians);

void gb_free_document(GBDocument document);

const char *gb_occt_version(void);

#ifdef __cplusplus
}
#endif

#endif
