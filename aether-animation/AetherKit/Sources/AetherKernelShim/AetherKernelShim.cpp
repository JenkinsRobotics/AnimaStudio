#include "AetherKernelShim.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <mutex>
#include <string>
#include <type_traits>
#include <vector>

#include <BRep_Builder.hxx>
#include <BRepAdaptor_Curve.hxx>
#include <BRepMesh_IncrementalMesh.hxx>
#include <BRepPrimAPI_MakeBox.hxx>
#include <BRepPrimAPI_MakeCylinder.hxx>
#include <BRep_Tool.hxx>
#include <GCPnts_TangentialDeflection.hxx>
#include <IFSelect_ReturnStatus.hxx>
#include <OSD.hxx>
#include <Poly_Triangulation.hxx>
#include <Quantity_ColorRGBA.hxx>
#include <STEPCAFControl_Reader.hxx>
#include <Standard_ErrorHandler.hxx>
#include <Standard_Failure.hxx>
#include <Standard_Version.hxx>
#include <StdPrs_ToolTriangulatedShape.hxx>
#include <TCollection_AsciiString.hxx>
#include <TCollection_ExtendedString.hxx>
#include <TDataStd_Name.hxx>
#include <TDF_LabelSequence.hxx>
#include <TDocStd_Document.hxx>
#include <TopAbs_Orientation.hxx>
#include <TopExp_Explorer.hxx>
#include <TopLoc_Location.hxx>
#include <TopTools_MapOfShape.hxx>
#include <TopoDS.hxx>
#include <TopoDS_Compound.hxx>
#include <TopoDS_Edge.hxx>
#include <TopoDS_Face.hxx>
#include <TopoDS_Shape.hxx>
#include <XCAFApp_Application.hxx>
#include <XCAFDoc_ColorTool.hxx>
#include <XCAFDoc_DocumentTool.hxx>
#include <XCAFDoc_ShapeTool.hxx>
#include <gp_Ax2.hxx>
#include <gp_Dir.hxx>
#include <gp_Pnt.hxx>
#include <gp_Trsf.hxx>

namespace {

using Clock = std::chrono::steady_clock;

void configureSignalHandling() {
  static std::once_flag once;
  std::call_once(once, [] { OSD::SetSignal(Standard_False); });
}

double elapsed(Clock::time_point start) {
  return std::chrono::duration<double>(Clock::now() - start).count();
}

char *copyString(const std::string &value) {
  char *result = static_cast<char *>(std::malloc(value.size() + 1));
  if (result != nullptr) std::memcpy(result, value.c_str(), value.size() + 1);
  return result;
}

std::string failureMessage(const Standard_Failure &failure, const char *stage) {
  const char *detail = failure.GetMessageString();
  if (detail == nullptr || std::strlen(detail) == 0) {
    return std::string("Open CASCADE failed while ") + stage;
  }
  return std::string("Open CASCADE failed while ") + stage + ": " + detail;
}

std::string labelName(const TDF_Label &label, const std::string &fallback) {
  Handle(TDataStd_Name) attribute;
  if (label.FindAttribute(TDataStd_Name::GetID(), attribute)) {
    const TCollection_ExtendedString value = attribute->Get();
    const TCollection_AsciiString ascii(value, '?');
    if (!ascii.IsEmpty()) return ascii.ToCString();
  }
  return fallback;
}

void identity(double output[16]) {
  std::fill(output, output + 16, 0.0);
  output[0] = output[5] = output[10] = output[15] = 1.0;
}

void transformMatrix(const TopLoc_Location &location, double output[16]) {
  identity(output);
  if (location.IsIdentity()) return;
  const gp_Trsf transform = location.Transformation();
  for (int row = 1; row <= 3; ++row) {
    for (int column = 1; column <= 4; ++column) {
      output[(column - 1) * 4 + (row - 1)] = transform.Value(row, column);
    }
  }
}

struct NodeBuilder {
  std::string name;
  int32_t parent = -1;
  uint32_t firstFace = 0;
  uint32_t faceCount = 0;
  double transform[16];
  NodeBuilder() { identity(transform); }
};

struct DocumentBuilder {
  std::vector<float> positions;
  std::vector<float> normals;
  std::vector<uint32_t> indices;
  std::vector<ACFaceRange> faces;
  std::vector<float> edgePoints;
  std::vector<ACEdgeRange> edges;
  std::vector<NodeBuilder> nodes;
  double maximumToleranceM = 0.0;

  void appendFace(
      const TopoDS_Face &face,
      int32_t nodeIndex,
      int32_t topologyIndex,
      const Handle(XCAFDoc_ColorTool) &colors,
      const float fallbackColor[4]) {
    TopLoc_Location location;
    Handle(Poly_Triangulation) triangulation = BRep_Tool::Triangulation(face, location);
    if (triangulation.IsNull() || triangulation->NbTriangles() == 0) return;
    StdPrs_ToolTriangulatedShape::ComputeNormals(face, triangulation);
    const gp_Trsf transform = location.Transformation();
    const bool reversed = face.Orientation() == TopAbs_REVERSED;

    ACFaceRange range{};
    range.vertex_offset = static_cast<uint32_t>(positions.size() / 3);
    range.index_offset = static_cast<uint32_t>(indices.size());
    range.assembly_node = nodeIndex;
    range.topology_index = topologyIndex;
    std::copy(fallbackColor, fallbackColor + 4, range.color);

    Quantity_ColorRGBA faceColor;
    if (!colors.IsNull()
        && (colors->GetColor(face, XCAFDoc_ColorSurf, faceColor)
            || colors->GetColor(face, XCAFDoc_ColorGen, faceColor))) {
      range.color[0] = static_cast<float>(faceColor.GetRGB().Red());
      range.color[1] = static_cast<float>(faceColor.GetRGB().Green());
      range.color[2] = static_cast<float>(faceColor.GetRGB().Blue());
      range.color[3] = faceColor.Alpha();
    }

    for (Standard_Integer index = 1; index <= triangulation->NbNodes(); ++index) {
      const gp_Pnt point = triangulation->Node(index).Transformed(transform);
      positions.insert(
          positions.end(),
          {static_cast<float>(point.X() * 0.001), static_cast<float>(point.Y() * 0.001),
           static_cast<float>(point.Z() * 0.001)});
      gp_Dir normal = triangulation->HasNormals()
          ? triangulation->Normal(index)
          : gp_Dir(0.0, 0.0, 1.0);
      normal.Transform(transform);
      const float sign = reversed ? -1.0f : 1.0f;
      normals.insert(
          normals.end(),
          {static_cast<float>(normal.X()) * sign, static_cast<float>(normal.Y()) * sign,
           static_cast<float>(normal.Z()) * sign});
    }

    for (Standard_Integer index = 1; index <= triangulation->NbTriangles(); ++index) {
      Standard_Integer a = 0, b = 0, c = 0;
      triangulation->Triangle(index).Get(a, b, c);
      if (reversed) std::swap(b, c);
      indices.insert(
          indices.end(),
          {range.vertex_offset + static_cast<uint32_t>(a - 1),
           range.vertex_offset + static_cast<uint32_t>(b - 1),
           range.vertex_offset + static_cast<uint32_t>(c - 1)});
    }

    range.vertex_count = static_cast<uint32_t>(triangulation->NbNodes());
    range.index_count = static_cast<uint32_t>(triangulation->NbTriangles() * 3);
    faces.push_back(range);
    maximumToleranceM = std::max(maximumToleranceM, BRep_Tool::Tolerance(face) * 0.001);
  }

  void appendEdges(const TopoDS_Shape &shape, int32_t nodeIndex, double deflectionMm) {
    TopTools_MapOfShape seen;
    int32_t topologyIndex = 0;
    for (TopExp_Explorer explorer(shape, TopAbs_EDGE); explorer.More(); explorer.Next()) {
      const TopoDS_Edge edge = TopoDS::Edge(explorer.Current());
      if (!seen.Add(edge) || BRep_Tool::Degenerated(edge)) continue;
      BRepAdaptor_Curve curve(edge);
      GCPnts_TangentialDeflection sample(curve, 0.15, deflectionMm);
      if (sample.NbPoints() < 2) continue;
      ACEdgeRange range{};
      range.point_offset = static_cast<uint32_t>(edgePoints.size() / 3);
      range.point_count = static_cast<uint32_t>(sample.NbPoints());
      range.assembly_node = nodeIndex;
      range.topology_index = topologyIndex++;
      for (Standard_Integer index = 1; index <= sample.NbPoints(); ++index) {
        const gp_Pnt point = sample.Value(index);
        edgePoints.insert(
            edgePoints.end(),
            {static_cast<float>(point.X() * 0.001), static_cast<float>(point.Y() * 0.001),
             static_cast<float>(point.Z() * 0.001)});
      }
      maximumToleranceM = std::max(maximumToleranceM, BRep_Tool::Tolerance(edge) * 0.001);
      edges.push_back(range);
    }
  }

  void appendShape(
      const TopoDS_Shape &shape,
      int32_t nodeIndex,
      const Handle(XCAFDoc_ColorTool) &colors,
      const float fallbackColor[4],
      double deflectionMm,
      double angularDeflection) {
    if (shape.IsNull()) return;
    TopoDS_Shape copy = shape;
    BRepMesh_IncrementalMesh mesh(copy, deflectionMm, false, angularDeflection, true);
    const uint32_t firstFace = static_cast<uint32_t>(faces.size());
    int32_t topologyIndex = 0;
    for (TopExp_Explorer explorer(copy, TopAbs_FACE); explorer.More(); explorer.Next()) {
      appendFace(
          TopoDS::Face(explorer.Current()), nodeIndex, topologyIndex++, colors, fallbackColor);
    }
    nodes[static_cast<size_t>(nodeIndex)].firstFace = firstFace;
    nodes[static_cast<size_t>(nodeIndex)].faceCount =
        static_cast<uint32_t>(faces.size()) - firstFace;
    appendEdges(copy, nodeIndex, deflectionMm);
  }

  ACDocument release(
      double readSeconds,
      double transferSeconds,
      double triangulationSeconds,
      const std::string &error = {}) {
    ACDocument document{};
    document.vertex_count = static_cast<uint32_t>(positions.size() / 3);
    document.index_count = static_cast<uint32_t>(indices.size());
    document.face_count = static_cast<uint32_t>(faces.size());
    document.edge_point_count = static_cast<uint32_t>(edgePoints.size() / 3);
    document.edge_count = static_cast<uint32_t>(edges.size());
    document.node_count = static_cast<uint32_t>(nodes.size());
    document.read_seconds = readSeconds;
    document.transfer_seconds = transferSeconds;
    document.triangulation_seconds = triangulationSeconds;
    document.maximum_tolerance_m = maximumToleranceM;
    document.error_message = error.empty() ? nullptr : copyString(error);

    auto copyVector = [](const auto &source, auto **destination) {
      using Value = typename std::decay_t<decltype(source)>::value_type;
      if (source.empty()) {
        *destination = nullptr;
        return;
      }
      *destination = static_cast<Value *>(std::malloc(sizeof(Value) * source.size()));
      std::memcpy(*destination, source.data(), sizeof(Value) * source.size());
    };
    copyVector(positions, &document.positions);
    copyVector(normals, &document.normals);
    copyVector(indices, &document.indices);
    copyVector(faces, &document.faces);
    copyVector(edgePoints, &document.edge_points);
    copyVector(edges, &document.edges);

    if (!nodes.empty()) {
      document.nodes = static_cast<ACAssemblyNode *>(
          std::calloc(nodes.size(), sizeof(ACAssemblyNode)));
      for (size_t index = 0; index < nodes.size(); ++index) {
        document.nodes[index].name = copyString(nodes[index].name);
        document.nodes[index].parent_index = nodes[index].parent;
        document.nodes[index].first_face = nodes[index].firstFace;
        document.nodes[index].face_count = nodes[index].faceCount;
        std::copy(
            nodes[index].transform, nodes[index].transform + 16,
            document.nodes[index].transform);
      }
    }
    return document;
  }
};

float defaultColor[4] = {0.72f, 0.74f, 0.78f, 1.0f};

float *fallbackColor(
    const TDF_Label &label,
    const TopoDS_Shape &shape,
    const Handle(XCAFDoc_ColorTool) &colors,
    float output[4]) {
  std::copy(defaultColor, defaultColor + 4, output);
  if (colors.IsNull()) return output;
  Quantity_ColorRGBA color;
  if (colors->GetColor(label, XCAFDoc_ColorSurf, color)
      || colors->GetColor(label, XCAFDoc_ColorGen, color)
      || colors->GetColor(shape, XCAFDoc_ColorSurf, color)
      || colors->GetColor(shape, XCAFDoc_ColorGen, color)) {
    output[0] = static_cast<float>(color.GetRGB().Red());
    output[1] = static_cast<float>(color.GetRGB().Green());
    output[2] = static_cast<float>(color.GetRGB().Blue());
    output[3] = color.Alpha();
  }
  return output;
}

void appendLabel(
    const TDF_Label &label,
    int32_t parentIndex,
    const Handle(XCAFDoc_ShapeTool) &shapeTool,
    const Handle(XCAFDoc_ColorTool) &colors,
    DocumentBuilder &builder,
    double deflectionMm,
    double angularDeflection) {
  const int32_t nodeIndex = static_cast<int32_t>(builder.nodes.size());
  NodeBuilder node;
  node.parent = parentIndex;
  TDF_Label referred = label;
  if (shapeTool->IsReference(label)) shapeTool->GetReferredShape(label, referred);
  node.name = labelName(label, labelName(referred, "Unnamed CAD node"));
  const TopoDS_Shape locatedShape = shapeTool->GetShape(label);
  transformMatrix(locatedShape.Location(), node.transform);
  builder.nodes.push_back(node);

  TDF_LabelSequence components;
  shapeTool->GetComponents(referred, components, false);
  if (components.Length() > 0) {
    for (Standard_Integer index = 1; index <= components.Length(); ++index) {
      appendLabel(
          components.Value(index), nodeIndex, shapeTool, colors, builder,
          deflectionMm, angularDeflection);
    }
    return;
  }

  float color[4];
  fallbackColor(referred, locatedShape, colors, color);
  builder.appendShape(
      locatedShape, nodeIndex, colors, color, deflectionMm, angularDeflection);
}

ACDocument errorDocument(const std::string &message, double readSeconds = 0.0) {
  DocumentBuilder builder;
  return builder.release(readSeconds, 0.0, 0.0, message);
}

}  // namespace

ACDocument aether_kernel_load_step(
    const char *path,
    double linearDeflectionM,
    double angularDeflectionRadians) {
  if (path == nullptr || std::strlen(path) == 0) return errorDocument("No STEP path supplied");
  const double deflectionMm = std::max(linearDeflectionM * 1000.0, 1.0e-6);
  const double angular = std::clamp(angularDeflectionRadians, 1.0e-6, M_PI);
  configureSignalHandling();

  const auto importStart = Clock::now();
  const char *stage = "initializing the STEP importer";
  try {
    OCC_CATCH_SIGNALS

    Handle(TDocStd_Document) document;
    XCAFApp_Application::GetApplication()->NewDocument("MDTV-XCAF", document);
    STEPCAFControl_Reader reader;
    reader.SetColorMode(true);
    reader.SetNameMode(true);
    reader.SetLayerMode(true);
    reader.SetMatMode(true);

    stage = "reading the STEP file";
    const auto readStart = Clock::now();
    const IFSelect_ReturnStatus status = reader.ReadFile(path);
    const double readSeconds = elapsed(readStart);
    if (status != IFSelect_RetDone) {
      return errorDocument("Open CASCADE could not read the STEP file", readSeconds);
    }

    stage = "transferring STEP geometry";
    const auto transferStart = Clock::now();
    if (!reader.Transfer(document)) {
      return errorDocument(
          "Open CASCADE could not transfer the STEP XDE document", readSeconds);
    }
    const double transferSeconds = elapsed(transferStart);

    const Handle(XCAFDoc_ShapeTool) shapeTool =
        XCAFDoc_DocumentTool::ShapeTool(document->Main());
    const Handle(XCAFDoc_ColorTool) colorTool =
        XCAFDoc_DocumentTool::ColorTool(document->Main());
    TDF_LabelSequence roots;
    shapeTool->GetFreeShapes(roots);
    if (roots.Length() == 0) {
      return errorDocument("STEP document contains no transferable shapes", readSeconds);
    }

    stage = "triangulating STEP geometry";
    DocumentBuilder builder;
    const auto meshStart = Clock::now();
    for (Standard_Integer index = 1; index <= roots.Length(); ++index) {
      appendLabel(
          roots.Value(index), -1, shapeTool, colorTool, builder, deflectionMm, angular);
    }
    return builder.release(readSeconds, transferSeconds, elapsed(meshStart));
  } catch (const Standard_Failure &failure) {
    return errorDocument(failureMessage(failure, stage), elapsed(importStart));
  } catch (const std::exception &failure) {
    return errorDocument(
        std::string("STEP import failed while ") + stage + ": " + failure.what(),
        elapsed(importStart));
  } catch (...) {
    return errorDocument(
        std::string("STEP import failed while ") + stage + " with an unknown native error",
        elapsed(importStart));
  }
}

ACDocument aether_kernel_make_test_document(
    double linearDeflectionM,
    double angularDeflectionRadians) {
  configureSignalHandling();
  const auto kernelStart = Clock::now();
  TopoDS_Compound assembly;
  BRep_Builder shapeBuilder;
  shapeBuilder.MakeCompound(assembly);
  shapeBuilder.Add(assembly, BRepPrimAPI_MakeBox(60.0, 40.0, 18.0).Shape());
  const gp_Ax2 axis(gp_Pnt(30.0, 20.0, 18.0), gp_Dir(0.0, 0.0, 1.0));
  shapeBuilder.Add(assembly, BRepPrimAPI_MakeCylinder(axis, 10.0, 24.0).Shape());
  const double kernelSeconds = elapsed(kernelStart);

  DocumentBuilder builder;
  NodeBuilder root;
  root.name = "Kernel test assembly";
  builder.nodes.push_back(root);
  const auto meshStart = Clock::now();
  builder.appendShape(
      assembly, 0, Handle(XCAFDoc_ColorTool)(), defaultColor,
      std::max(linearDeflectionM * 1000.0, 1.0e-6),
      std::clamp(angularDeflectionRadians, 1.0e-6, M_PI));
  return builder.release(kernelSeconds, 0.0, elapsed(meshStart));
}

void aether_kernel_free_document(ACDocument document) {
  std::free(document.positions);
  std::free(document.normals);
  std::free(document.indices);
  std::free(document.faces);
  std::free(document.edge_points);
  std::free(document.edges);
  for (uint32_t index = 0; index < document.node_count; ++index) {
    std::free(document.nodes[index].name);
  }
  std::free(document.nodes);
  std::free(document.error_message);
}

const char *aether_kernel_open_cascade_version(void) { return OCC_VERSION_COMPLETE; }
