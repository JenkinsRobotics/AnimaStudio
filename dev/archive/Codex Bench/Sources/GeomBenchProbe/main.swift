import Foundation
import GeomBenchCore

let arguments = Array(CommandLine.arguments.dropFirst())
do {
  guard !arguments.isEmpty else {
    FileHandle.standardError.write(
      Data("usage: geom-probe /path/to/file.step [/path/to/another.step ...]\n".utf8))
    exit(EXIT_FAILURE)
  }
  let documents = try arguments.map { path in
    try GeometryDocument.loadSTEP(URL(fileURLWithPath: path))
  }
  let document = try GeometryDocument.merging(documents)
  let metrics = document.metrics
  print("sources=\(document.sourceURLs.count)")
  print("source=\(document.sourceURL?.path ?? arguments[0])")
  print("occt=\(GeomKernel.version)")
  print("nodes=\(document.nodes.count)")
  print("faces=\(document.faces.count)")
  print("edges=\(document.edges.count)")
  print("triangles=\(document.triangleCount)")
  print("render_vertices=\(document.renderGeometry.vertexCount)")
  print("render_batches=\(document.renderGeometry.batches.count)")
  print("render_parts=\(document.renderGeometry.partCount)")
  print("edge_segments=\(document.renderGeometry.edgeSegmentCount)")
  print(String(format: "read_ms=%.3f", metrics.readMilliseconds))
  print(String(format: "transfer_ms=%.3f", metrics.transferMilliseconds))
  print(String(format: "triangulation_ms=%.3f", metrics.triangulationMilliseconds))
  print(String(format: "maximum_tolerance_m=%.12g", metrics.maximumToleranceMetres))
} catch {
  FileHandle.standardError.write(Data("geom-probe: \(error.localizedDescription)\n".utf8))
  exit(EXIT_FAILURE)
}
