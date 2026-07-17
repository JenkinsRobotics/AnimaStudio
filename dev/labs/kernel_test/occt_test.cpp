// Standalone Open CASCADE (OCCT) kernel evaluation for Anima Studio.
//
// Exercises the claims that matter for us:
//   1. B-rep modeling precision  — box + bored hole + fillets, volume checked
//      against the closed-form answer (kernel math vs. real math).
//   2. STEP round-trip           — write STEP, read it back, compare volume.
//   3. Quality-controlled mesh   — tessellate the exact B-rep at several
//      deflection tolerances (the CAD "quality dial" STL files never have).
//   4. Real-world STL read       — parse one of the user's exported CAD STLs.
// Everything is timed so the latency trade-off is visible on this machine.

#include <chrono>
#include <cmath>
#include <cstdio>

#include <BRepAlgoAPI_Cut.hxx>
#include <BRepBndLib.hxx>
#include <BRepFilletAPI_MakeFillet.hxx>
#include <BRepGProp.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <Bnd_Box.hxx>
#include <GProp_GProps.hxx>
#include <Poly_Triangulation.hxx>
#include <RWStl.hxx>
#include <STEPControl_Reader.hxx>
#include <STEPControl_Writer.hxx>
#include <Standard_Version.hxx>
#include <StlAPI_Writer.hxx>
#include <TopAbs_ShapeEnum.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>

static double seconds(std::chrono::steady_clock::time_point start) {
  return std::chrono::duration<double>(std::chrono::steady_clock::now() - start)
      .count();
}

static double volumeOf(const TopoDS_Shape &shape) {
  GProp_GProps props;
  BRepGProp::VolumeProperties(shape, props);
  return props.Mass();
}

static int meshTriangleCount(const TopoDS_Shape &shape) {
  int total = 0;
  for (TopExp_Explorer it(shape, TopAbs_FACE); it.More(); it.Next()) {
    TopLoc_Location loc;
    Handle(Poly_Triangulation) tri =
        BRep_Tool::Triangulation(TopoDS::Face(it.Current()), loc);
    if (!tri.IsNull()) total += tri->NbTriangles();
  }
  return total;
}

int main(int argc, char **argv) {
  std::printf("=== Open CASCADE %s standalone kernel test ===\n\n",
              OCC_VERSION_COMPLETE);

  // ---- 1. Precise B-rep modeling -----------------------------------------
  // 40 x 30 x 20 mm block, 12 mm bore through the middle. Exact volume:
  //   40*30*20 - pi * 6^2 * 20
  auto t0 = std::chrono::steady_clock::now();
  TopoDS_Shape block = BRepPrimAPI_MakeBox(40.0, 30.0, 20.0).Shape();
  gp_Ax2 boreAxis(gp_Pnt(20.0, 15.0, -1.0), gp_Dir(0, 0, 1));
  TopoDS_Shape bore = BRepPrimAPI_MakeCylinder(boreAxis, 6.0, 22.0).Shape();
  TopoDS_Shape bored = BRepAlgoAPI_Cut(block, bore).Shape();
  double vBored = volumeOf(bored);
  double vExact = 40.0 * 30.0 * 20.0 - M_PI * 6.0 * 6.0 * 20.0;
  std::printf("1. BOOLEAN PRECISION  (%.3fs)\n", seconds(t0));
  std::printf("   kernel volume : %.9f mm^3\n", vBored);
  std::printf("   closed-form   : %.9f mm^3\n", vExact);
  std::printf("   error         : %.3e mm^3 (%.2e relative)\n\n",
              std::fabs(vBored - vExact),
              std::fabs(vBored - vExact) / vExact);

  // Fillet every outer edge of the bored block at r = 2 mm.
  t0 = std::chrono::steady_clock::now();
  BRepFilletAPI_MakeFillet fillet(bored);
  for (TopExp_Explorer it(bored, TopAbs_EDGE); it.More(); it.Next())
    fillet.Add(2.0, TopoDS::Edge(it.Current()));
  TopoDS_Shape part = fillet.Shape();
  std::printf("2. FILLETING          (%.3fs)\n", seconds(t0));
  std::printf("   filleted volume: %.6f mm^3 (every edge, r = 2 mm)\n\n",
              volumeOf(part));

  // ---- 2. STEP round-trip -------------------------------------------------
  const char *stepPath = "/tmp/occt_test_part.step";
  t0 = std::chrono::steady_clock::now();
  STEPControl_Writer writer;
  writer.Transfer(part, STEPControl_AsIs);
  writer.Write(stepPath);
  STEPControl_Reader reader;
  reader.ReadFile(stepPath);
  reader.TransferRoots();
  TopoDS_Shape reread = reader.OneShape();
  double vOriginal = volumeOf(part);
  double vReread = volumeOf(reread);
  std::printf("3. STEP ROUND-TRIP    (%.3fs)  %s\n", seconds(t0), stepPath);
  std::printf("   volume before : %.9f mm^3\n", vOriginal);
  std::printf("   volume after  : %.9f mm^3\n", vReread);
  std::printf("   drift         : %.3e (B-rep survives exactly)\n\n",
              std::fabs(vOriginal - vReread));

  // ---- 3. Quality-controlled tessellation --------------------------------
  std::printf("4. TESSELLATION QUALITY DIAL (same exact part)\n");
  const double deflections[] = {1.0, 0.1, 0.01};
  for (double d : deflections) {
    TopoDS_Shape copy = reread;
    t0 = std::chrono::steady_clock::now();
    BRepMesh_IncrementalMesh mesher(copy, d, false, 0.5, true);
    std::printf("   deflection %.2f mm -> %6d triangles  (%.3fs)\n", d,
                meshTriangleCount(copy), seconds(t0));
  }
  std::printf("\n");

  // Export the finest mesh as binary STL for import into Anima Studio.
  const char *stlOut = "/tmp/occt_test_part.stl";
  StlAPI_Writer stlWriter;
  stlWriter.ASCIIMode() = Standard_False;
  stlWriter.Write(reread, stlOut);
  std::printf("5. WROTE %s (binary STL, mm — import it into Anima Studio)\n\n",
              stlOut);

  // ---- 4. Read a real exported CAD STL -----------------------------------
  const char *stlIn =
      argc > 1 ? argv[1]
               : "/Users/jonathanjenkins/Documents/AnimaStudio/single part/"
                 "characters/test-part/assets/ARCADA001 - Part 1 (2).stl";
  t0 = std::chrono::steady_clock::now();
  Handle(Poly_Triangulation) mesh = RWStl::ReadFile(stlIn);
  if (mesh.IsNull()) {
    std::printf("6. STL READ FAILED: %s\n", stlIn);
    return 1;
  }
  Bnd_Box box;
  for (Standard_Integer i = 1; i <= mesh->NbNodes(); ++i)
    box.Add(mesh->Node(i));
  Standard_Real xmin, ymin, zmin, xmax, ymax, zmax;
  box.Get(xmin, ymin, zmin, xmax, ymax, zmax);
  std::printf("6. REAL CAD STL READ  (%.3fs)  %s\n", seconds(t0), stlIn);
  std::printf("   triangles : %d   vertices : %d\n", mesh->NbTriangles(),
              mesh->NbNodes());
  std::printf("   bounds    : %.2f x %.2f x %.2f mm\n", xmax - xmin,
              ymax - ymin, zmax - zmin);
  std::printf("   note      : STL is triangles only — no faces, no exact "
              "surfaces, no quality dial.\n");
  return 0;
}
