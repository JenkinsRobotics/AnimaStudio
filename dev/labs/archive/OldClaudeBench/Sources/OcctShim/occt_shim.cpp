// OCCT kernel behind a C ABI. All the C++ stays on this side of the wall.
#include "include/occt_shim.h"

#include <chrono>
#include <cstring>
#include <vector>

#include <BRepAdaptor_Curve.hxx>
#include <BRepAlgoAPI_Cut.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <TopTools_MapOfShape.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <Poly_Connect.hxx>
#include <Poly_Triangulation.hxx>
#include <BRep_Builder.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <RWObj.hxx>
#include <RWStl.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <STEPControl_Reader.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDocStd_Document.hxx>
#include <TopoDS_Compound.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <StdPrs_ToolTriangulatedShape.hxx>
#include <TopAbs_Orientation.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>

namespace {

double seconds(std::chrono::steady_clock::time_point start) {
  return std::chrono::duration<double>(std::chrono::steady_clock::now() - start)
      .count();
}

struct MeshAccumulator {
  std::vector<float> positions;
  std::vector<float> normals;
  std::vector<uint32_t> indices;

  void addFace(const TopoDS_Face &face, double scale) {
    TopLoc_Location loc;
    Handle(Poly_Triangulation) tri = BRep_Tool::Triangulation(face, loc);
    if (tri.IsNull()) return;
    StdPrs_ToolTriangulatedShape::ComputeNormals(face, tri);
    const gp_Trsf &trsf = loc.Transformation();
    const bool reversed = face.Orientation() == TopAbs_REVERSED;
    const uint32_t base = (uint32_t)(positions.size() / 3);
    for (Standard_Integer i = 1; i <= tri->NbNodes(); ++i) {
      gp_Pnt p = tri->Node(i).Transformed(trsf);
      positions.push_back((float)(p.X() * scale));
      positions.push_back((float)(p.Y() * scale));
      positions.push_back((float)(p.Z() * scale));
      gp_Dir n = tri->HasNormals() ? tri->Normal(i) : gp_Dir(0, 0, 1);
      n.Transform(trsf);
      double flip = reversed ? -1.0 : 1.0;
      normals.push_back((float)(n.X() * flip));
      normals.push_back((float)(n.Y() * flip));
      normals.push_back((float)(n.Z() * flip));
    }
    for (Standard_Integer i = 1; i <= tri->NbTriangles(); ++i) {
      Standard_Integer a, b, c;
      tri->Triangle(i).Get(a, b, c);
      if (reversed) std::swap(b, c);
      indices.push_back(base + (uint32_t)(a - 1));
      indices.push_back(base + (uint32_t)(b - 1));
      indices.push_back(base + (uint32_t)(c - 1));
    }
  }

  OcctMesh release(double kernelSeconds, double meshSeconds) {
    OcctMesh out;
    out.color[0] = 0.72f;
    out.color[1] = 0.74f;
    out.color[2] = 0.78f;
    out.color[3] = 1.0f;
    out.has_color = 0;
    out.vertex_count = (int32_t)(positions.size() / 3);
    out.triangle_count = (int32_t)(indices.size() / 3);
    out.kernel_seconds = kernelSeconds;
    out.mesh_seconds = meshSeconds;
    out.positions = (float *)std::malloc(positions.size() * sizeof(float));
    out.normals = (float *)std::malloc(normals.size() * sizeof(float));
    out.indices = (uint32_t *)std::malloc(indices.size() * sizeof(uint32_t));
    std::memcpy(out.positions, positions.data(), positions.size() * sizeof(float));
    std::memcpy(out.normals, normals.data(), normals.size() * sizeof(float));
    std::memcpy(out.indices, indices.data(), indices.size() * sizeof(uint32_t));
    return out;
  }
};

OcctMesh emptyMesh() {
  OcctMesh out;
  std::memset(&out, 0, sizeof(out));
  return out;
}

OcctMesh meshShape(const TopoDS_Shape &shape, double deflectionMm,
                   double kernelSeconds, double scale) {
  auto t0 = std::chrono::steady_clock::now();
  TopoDS_Shape copy = shape;
  BRepMesh_IncrementalMesh mesher(copy, deflectionMm, false, 0.5, true);
  MeshAccumulator acc;
  for (TopExp_Explorer it(copy, TopAbs_FACE); it.More(); it.Next())
    acc.addFace(TopoDS::Face(it.Current()), scale);
  return acc.release(kernelSeconds, seconds(t0));
}

}  // namespace

OcctMesh occt_make_demo_part(double deflection_mm) {
  auto t0 = std::chrono::steady_clock::now();
  TopoDS_Shape block = BRepPrimAPI_MakeBox(40.0, 30.0, 20.0).Shape();
  gp_Ax2 boreAxis(gp_Pnt(20.0, 15.0, -1.0), gp_Dir(0, 0, 1));
  TopoDS_Shape bored =
      BRepAlgoAPI_Cut(block,
                      BRepPrimAPI_MakeCylinder(boreAxis, 6.0, 22.0).Shape())
          .Shape();
  BRepFilletAPI_MakeFillet fillet(bored);
  for (TopExp_Explorer it(bored, TopAbs_EDGE); it.More(); it.Next())
    fillet.Add(2.0, TopoDS::Edge(it.Current()));
  TopoDS_Shape part = fillet.Shape();
  return meshShape(part, deflection_mm, seconds(t0), 0.001);
}

OcctMesh occt_load_step(const char *path, double deflection_mm) {
  auto t0 = std::chrono::steady_clock::now();
  STEPControl_Reader reader;
  if (reader.ReadFile(path) != IFSelect_RetDone) return emptyMesh();
  reader.TransferRoots();
  TopoDS_Shape shape = reader.OneShape();
  if (shape.IsNull()) return emptyMesh();
  return meshShape(shape, deflection_mm, seconds(t0), 0.001);
}

namespace {
OcctMesh meshFromTriangulation(Handle(Poly_Triangulation) tri,
                               double scale_to_meters,
                               std::chrono::steady_clock::time_point t0);
}

OcctMesh occt_load_obj(const char *path, double scale_to_meters) {
  auto t0 = std::chrono::steady_clock::now();
  Handle(Poly_Triangulation) tri = RWObj::ReadFile(path);
  if (tri.IsNull()) return emptyMesh();
  return meshFromTriangulation(tri, scale_to_meters, t0);
}

OcctMesh occt_load_stl(const char *path, double scale_to_meters) {
  auto t0 = std::chrono::steady_clock::now();
  Handle(Poly_Triangulation) tri = RWStl::ReadFile(path);
  if (tri.IsNull()) return emptyMesh();
  return meshFromTriangulation(tri, scale_to_meters, t0);
}

namespace {
OcctMesh meshFromTriangulation(Handle(Poly_Triangulation) tri,
                               double scale_to_meters,
                               std::chrono::steady_clock::time_point t0) {
  // Wrap the raw triangulation in a face so normal computation applies.
  MeshAccumulator acc;
  tri->ComputeNormals();
  const uint32_t base = 0;
  for (Standard_Integer i = 1; i <= tri->NbNodes(); ++i) {
    gp_Pnt p = tri->Node(i);
    acc.positions.push_back((float)(p.X() * scale_to_meters));
    acc.positions.push_back((float)(p.Y() * scale_to_meters));
    acc.positions.push_back((float)(p.Z() * scale_to_meters));
    gp_Dir n = tri->HasNormals() ? tri->Normal(i) : gp_Dir(0, 0, 1);
    acc.normals.push_back((float)n.X());
    acc.normals.push_back((float)n.Y());
    acc.normals.push_back((float)n.Z());
  }
  for (Standard_Integer i = 1; i <= tri->NbTriangles(); ++i) {
    Standard_Integer a, b, c;
    tri->Triangle(i).Get(a, b, c);
    acc.indices.push_back(base + (uint32_t)(a - 1));
    acc.indices.push_back(base + (uint32_t)(b - 1));
    acc.indices.push_back(base + (uint32_t)(c - 1));
  }
  return acc.release(0.0, seconds(t0));
}
}  // namespace

void occt_free_mesh(OcctMesh mesh) {
  std::free(mesh.positions);
  std::free(mesh.normals);
  std::free(mesh.indices);
}

// ---- Structured face/edge extraction --------------------------------------

namespace {

OcctShapeSet emptySet() {
  OcctShapeSet set;
  std::memset(&set, 0, sizeof(set));
  return set;
}

// Tessellate, then emit each FACE as its own mesh and each unique EDGE as a
// sampled polyline. This is the CAD selection structure STL files cannot
// carry — only B-rep (STEP / kernel-built) shapes have it. When an XCAF
// color tool is supplied, each face carries the color the CAD author gave it.
OcctShapeSet shapeSet(const TopoDS_Shape &shape, double deflectionMm,
                      double kernelSeconds,
                      const Handle(XCAFDoc_ColorTool) &colorTool =
                          Handle(XCAFDoc_ColorTool)(),
                      const float *fallbackRGBA = nullptr) {
  auto t0 = std::chrono::steady_clock::now();
  TopoDS_Shape copy = shape;
  BRepMesh_IncrementalMesh mesher(copy, deflectionMm, false, 0.5, true);
  const double scale = 0.001;  // mm -> m

  std::vector<OcctMesh> faces;
  for (TopExp_Explorer it(copy, TopAbs_FACE); it.More(); it.Next()) {
    MeshAccumulator acc;
    acc.addFace(TopoDS::Face(it.Current()), scale);
    if (acc.indices.empty()) continue;
    OcctMesh mesh = acc.release(0.0, 0.0);
    Quantity_ColorRGBA rgba;
    if (!colorTool.IsNull()
        && (colorTool->GetColor(it.Current(), XCAFDoc_ColorSurf, rgba)
            || colorTool->GetColor(it.Current(), XCAFDoc_ColorGen, rgba))) {
      mesh.color[0] = (float)rgba.GetRGB().Red();
      mesh.color[1] = (float)rgba.GetRGB().Green();
      mesh.color[2] = (float)rgba.GetRGB().Blue();
      mesh.color[3] = rgba.Alpha();
      mesh.has_color = 1;
    } else if (fallbackRGBA != nullptr) {
      // Body-level color (one STYLED_ITEM for the whole solid) — the common
      // export shape from Onshape/SolidWorks when faces aren't painted.
      std::memcpy(mesh.color, fallbackRGBA, sizeof(float) * 4);
      mesh.has_color = 1;
    }
    faces.push_back(mesh);
  }

  std::vector<OcctPolyline> edges;
  TopTools_MapOfShape seen;
  for (TopExp_Explorer it(copy, TopAbs_EDGE); it.More(); it.Next()) {
    const TopoDS_Edge &edge = TopoDS::Edge(it.Current());
    if (!seen.Add(edge)) continue;
    if (BRep_Tool::Degenerated(edge)) continue;
    BRepAdaptor_Curve curve(edge);
    GCPnts_TangentialDeflection sampler(curve, 0.25, deflectionMm);
    if (sampler.NbPoints() < 2) continue;
    OcctPolyline line;
    line.point_count = sampler.NbPoints();
    line.points = (float *)std::malloc(sizeof(float) * 3 * line.point_count);
    for (Standard_Integer i = 1; i <= sampler.NbPoints(); ++i) {
      gp_Pnt p = sampler.Value(i);
      line.points[(i - 1) * 3 + 0] = (float)(p.X() * scale);
      line.points[(i - 1) * 3 + 1] = (float)(p.Y() * scale);
      line.points[(i - 1) * 3 + 2] = (float)(p.Z() * scale);
    }
    edges.push_back(line);
  }

  OcctShapeSet set;
  set.face_count = (int32_t)faces.size();
  set.edge_count = (int32_t)edges.size();
  set.kernel_seconds = kernelSeconds;
  set.mesh_seconds = seconds(t0);
  set.faces = (OcctMesh *)std::malloc(sizeof(OcctMesh) * faces.size());
  set.edges = (OcctPolyline *)std::malloc(sizeof(OcctPolyline) * edges.size());
  std::memcpy(set.faces, faces.data(), sizeof(OcctMesh) * faces.size());
  std::memcpy(set.edges, edges.data(), sizeof(OcctPolyline) * edges.size());
  return set;
}

TopoDS_Shape buildDemoPart() {
  TopoDS_Shape block = BRepPrimAPI_MakeBox(40.0, 30.0, 20.0).Shape();
  gp_Ax2 boreAxis(gp_Pnt(20.0, 15.0, -1.0), gp_Dir(0, 0, 1));
  TopoDS_Shape bored =
      BRepAlgoAPI_Cut(block,
                      BRepPrimAPI_MakeCylinder(boreAxis, 6.0, 22.0).Shape())
          .Shape();
  BRepFilletAPI_MakeFillet fillet(bored);
  for (TopExp_Explorer it(bored, TopAbs_EDGE); it.More(); it.Next())
    fillet.Add(2.0, TopoDS::Edge(it.Current()));
  return fillet.Shape();
}

}  // namespace

OcctShapeSet occt_load_step_set(const char *path, double deflection_mm) {
  auto t0 = std::chrono::steady_clock::now();
  // XCAF (Extended Data Exchange) route: unlike the flat STEPControl_Reader,
  // this preserves assembly structure and the colors the CAD author assigned,
  // queryable per face via XCAFDoc_ColorTool.
  Handle(TDocStd_Document) doc;
  XCAFApp_Application::GetApplication()->NewDocument("MDTV-XCAF", doc);
  STEPCAFControl_Reader reader;
  reader.SetColorMode(true);
  reader.SetNameMode(true);
  if (reader.ReadFile(path) != IFSelect_RetDone) return emptySet();
  if (!reader.Transfer(doc)) return emptySet();
  Handle(XCAFDoc_ShapeTool) shapeTool =
      XCAFDoc_DocumentTool::ShapeTool(doc->Main());
  Handle(XCAFDoc_ColorTool) colorTool =
      XCAFDoc_DocumentTool::ColorTool(doc->Main());
  TDF_LabelSequence roots;
  shapeTool->GetFreeShapes(roots);
  if (roots.IsEmpty()) return emptySet();
  TopoDS_Compound compound;
  BRep_Builder builder;
  builder.MakeCompound(compound);
  // Body-level color fallback: colors commonly attach to the solid, not to
  // individual faces. Search the roots and their subshapes for the first
  // surface/generic color and use it for otherwise-uncolored faces.
  float fallback[4] = {0, 0, 0, 1};
  bool hasFallback = false;
  for (Standard_Integer i = 1; i <= roots.Length(); ++i) {
    TopoDS_Shape rootShape = shapeTool->GetShape(roots.Value(i));
    builder.Add(compound, rootShape);
    if (hasFallback) continue;
    Quantity_ColorRGBA rgba;
    bool found = colorTool->GetColor(rootShape, XCAFDoc_ColorSurf, rgba)
        || colorTool->GetColor(rootShape, XCAFDoc_ColorGen, rgba);
    if (!found) {
      for (TopExp_Explorer solids(rootShape, TopAbs_SOLID);
           !found && solids.More(); solids.Next()) {
        found = colorTool->GetColor(solids.Current(), XCAFDoc_ColorSurf, rgba)
            || colorTool->GetColor(solids.Current(), XCAFDoc_ColorGen, rgba);
      }
    }
    if (found) {
      fallback[0] = (float)rgba.GetRGB().Red();
      fallback[1] = (float)rgba.GetRGB().Green();
      fallback[2] = (float)rgba.GetRGB().Blue();
      fallback[3] = rgba.Alpha();
      hasFallback = true;
    }
  }
  return shapeSet(compound, deflection_mm, seconds(t0), colorTool,
                  hasFallback ? fallback : nullptr);
}

OcctShapeSet occt_demo_part_set(double deflection_mm) {
  auto t0 = std::chrono::steady_clock::now();
  TopoDS_Shape part = buildDemoPart();
  return shapeSet(part, deflection_mm, seconds(t0));
}

void occt_free_shape_set(OcctShapeSet set) {
  for (int32_t i = 0; i < set.face_count; ++i) occt_free_mesh(set.faces[i]);
  for (int32_t i = 0; i < set.edge_count; ++i) std::free(set.edges[i].points);
  std::free(set.faces);
  std::free(set.edges);
}
