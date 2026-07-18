// STEP -> OBJ+MTL converter for the Unity demo pipeline.
// Uses the same Open CASCADE shim as Claude Bench, so Unity receives the
// identical tessellation + per-face CAD colors the native pipelines show.
//   step_to_obj <in.step> <out_basename>   -> out_basename.obj / .mtl
#include "occt_shim.h"

#include <cstdio>
#include <string>

int main(int argc, char **argv) {
  if (argc < 3) {
    std::fprintf(stderr, "usage: step_to_obj <in.step> <out_basename>\n");
    return 2;
  }
  OcctShapeSet set = occt_load_step_set(argv[1], 0.05);
  if (set.face_count == 0) {
    std::fprintf(stderr, "STEP load failed: %s\n", argv[1]);
    return 1;
  }
  std::string base = argv[2];
  FILE *obj = std::fopen((base + ".obj").c_str(), "w");
  FILE *mtl = std::fopen((base + ".mtl").c_str(), "w");
  if (!obj || !mtl) {
    std::fprintf(stderr, "cannot open output files\n");
    return 1;
  }
  std::string mtlName = base.substr(base.find_last_of('/') + 1) + ".mtl";
  std::fprintf(obj, "# Anima Studio labs: %s\nmtllib %s\n", argv[1], mtlName.c_str());

  long vertexBase = 1;  // OBJ indices are 1-based, shared across groups
  int triangles = 0;
  for (int f = 0; f < set.face_count; ++f) {
    const OcctMesh &face = set.faces[f];
    std::fprintf(mtl, "newmtl face%d\nKd %.4f %.4f %.4f\n\n", f,
                 face.color[0], face.color[1], face.color[2]);
    std::fprintf(obj, "g face%d\nusemtl face%d\n", f, f);
    for (int i = 0; i < face.vertex_count; ++i) {
      std::fprintf(obj, "v %.6f %.6f %.6f\n", face.positions[i * 3],
                   face.positions[i * 3 + 1], face.positions[i * 3 + 2]);
      std::fprintf(obj, "vn %.4f %.4f %.4f\n", face.normals[i * 3],
                   face.normals[i * 3 + 1], face.normals[i * 3 + 2]);
    }
    for (int t = 0; t < face.triangle_count; ++t) {
      long a = vertexBase + face.indices[t * 3];
      long b = vertexBase + face.indices[t * 3 + 1];
      long c = vertexBase + face.indices[t * 3 + 2];
      std::fprintf(obj, "f %ld//%ld %ld//%ld %ld//%ld\n", a, a, b, b, c, c);
    }
    vertexBase += face.vertex_count;
    triangles += face.triangle_count;
  }
  std::fclose(obj);
  std::fclose(mtl);
  std::printf("WROTE %s.obj/.mtl  faces=%d triangles=%d\n", base.c_str(),
              set.face_count, triangles);
  occt_free_shape_set(set);
  return 0;
}
