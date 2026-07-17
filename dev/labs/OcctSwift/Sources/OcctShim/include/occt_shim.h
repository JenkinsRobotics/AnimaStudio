// C ABI over the Open CASCADE C++ kernel — the narrow waist Swift talks to.
#ifndef OCCT_SHIM_H
#define OCCT_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Flat triangle mesh with per-vertex normals, produced by OCCT tessellation.
typedef struct {
  float *positions;      // xyz * vertex_count (meters)
  float *normals;        // xyz * vertex_count
  uint32_t *indices;     // 3 * triangle_count
  int32_t vertex_count;
  int32_t triangle_count;
  double kernel_seconds; // time spent in B-rep modeling (if any)
  double mesh_seconds;   // time spent tessellating / reading
  float color[4];        // face RGBA from STEP (XCAF), else a neutral default
  int32_t has_color;     // 1 when the CAD file actually assigned a color
} OcctMesh;

// Exact B-rep demo part (box + bore + fillets, mm), tessellated at
// `deflection_mm`. Positions are scaled to meters.
OcctMesh occt_make_demo_part(double deflection_mm);

// Read a STEP file, tessellate every shape at `deflection_mm` (meters out).
// vertex_count == 0 on failure.
OcctMesh occt_load_step(const char *path, double deflection_mm);

// Read an STL file (unit passthrough * scale_to_meters).
OcctMesh occt_load_stl(const char *path, double scale_to_meters);

// Read an OBJ file (triangulation only, materials ignored).
OcctMesh occt_load_obj(const char *path, double scale_to_meters);

void occt_free_mesh(OcctMesh mesh);

// ---- Face/edge structured loading (B-rep only: STEP or the demo part) ----

typedef struct {
  float *points;       // xyz * point_count (meters)
  int32_t point_count;
} OcctPolyline;

typedef struct {
  OcctMesh *faces;     // one mesh per topological FACE
  int32_t face_count;
  OcctPolyline *edges; // one sampled polyline per topological EDGE
  int32_t edge_count;
  double kernel_seconds;
  double mesh_seconds;
} OcctShapeSet;

// STEP file -> per-face meshes + per-edge polylines. face_count == 0 on error.
OcctShapeSet occt_load_step_set(const char *path, double deflection_mm);

// The demo part (box + bore + fillets) in the same structured form.
OcctShapeSet occt_demo_part_set(double deflection_mm);

void occt_free_shape_set(OcctShapeSet set);

#ifdef __cplusplus
}
#endif
#endif
