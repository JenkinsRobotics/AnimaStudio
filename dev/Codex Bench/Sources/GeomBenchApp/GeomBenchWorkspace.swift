import GeomBenchCore
import SwiftUI

struct GeomBenchWorkspace: View {
  @Bindable var session: BenchSession
  @Environment(\.openSettings) private var openSettings

  var body: some View {
    NavigationSplitView {
      workspaceSidebar
        .navigationSplitViewColumnWidth(min: 220, ideal: 265, max: 340)
    } detail: {
      VStack(spacing: 0) {
        pipelineBar
        Divider()
        ZStack(alignment: .topTrailing) {
          viewport
          TelemetryHUD(session: session)
            .padding(14)
          VStack {
            Spacer()
            HStack {
              NavigationLegend()
              Spacer()
            }
          }
          .padding(14)
        }
        Divider()
        statusBar
      }
    }
    .background(session.theme.panelColor)
    .task { await session.runAutomatedBenchmarkIfRequested() }
  }

  private var workspaceSidebar: some View {
    VStack(spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("CODEX BENCH").font(.headline)
          Text("Multi-file test workspace").font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          session.presentOpenPanel()
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.borderless).help("Add files")
      }
      .padding(14)
      Divider()
      List(selection: $session.selectedFileID) {
        Section("FILES") {
          ForEach(session.files) { record in
            HStack(spacing: 8) {
              Image(systemName: record.kind == "B-Rep" ? "cube.transparent" : "doc")
                .foregroundStyle(record.status == "Failed" ? .red : .blue)
              VStack(alignment: .leading, spacing: 2) {
                Text(record.displayName).lineLimit(1)
                Text("\(record.kind) · \(record.status)")
                  .font(.caption2).foregroundStyle(.secondary)
              }
              Spacer()
            }
            .tag(record.id)
            .contextMenu {
              Button("Reload") { session.select(record) }
              Button("Remove from Workspace", role: .destructive) { session.remove(record) }
            }
          }
        }
        if let document = session.document {
          Section("ASSEMBLY") {
            OutlineGroup(nodeRoots(document), children: \.children) { node in
              Label(node.name, systemImage: node.children == nil ? "cube" : "square.stack.3d.up")
                .font(.caption)
            }
          }
        }
      }
      .onChange(of: session.selectedFileID) {
        guard let record = session.selectedFile else { return }
        session.select(record)
      }
      Divider()
      HStack {
        Button("Open…") { session.presentOpenPanel() }
        Spacer()
      }
      .padding(10)
    }
  }

  private var pipelineBar: some View {
    HStack(spacing: 12) {
      Button {
        openSettings()
      } label: {
        HStack(spacing: 10) {
          ZStack {
            RoundedRectangle(cornerRadius: 7).fill(Color.accentColor.opacity(0.16))
            Text("P\(session.pipeline.rawValue)")
              .font(.system(size: 10, weight: .bold, design: .rounded))
              .foregroundStyle(.tint)
          }
          .frame(width: 36, height: 30)
          VStack(alignment: .leading, spacing: 2) {
            Text(session.pipeline.comparisonName).font(.headline).lineLimit(1)
            Text(
              "\(session.pipeline.role.label) · \(session.theme.name)\(session.theme.isCustomized ? " · Custom" : "")"
            )
            .font(.caption).foregroundStyle(.secondary)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .help("Open Render Settings")
      VStack(alignment: .leading, spacing: 2) {
        Text(session.pipeline.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      Spacer()
      if session.isLoading { ProgressView().controlSize(.small) }
      Button {
        openSettings()
      } label: {
        Label("Render Settings", systemImage: "slider.horizontal.3")
      }
      Button {
        session.fitView()
      } label: {
        Label("Fit", systemImage: "arrow.up.left.and.arrow.down.right")
      }
      Button {
        session.presentOpenPanel()
      } label: {
        Label("Import", systemImage: "square.and.arrow.down")
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(.horizontal, 14)
    .frame(height: 58)
  }

  @ViewBuilder private var viewport: some View {
    switch session.pipeline {
    case .occtRealityKit:
      RealityKitBenchView(session: session, document: session.document)
    case .occtMetalKit:
      MetalBenchView(session: session, document: session.document)
    case .threeJSWebGPU:
      ThreeJSBenchView(session: session, document: session.document)
    case .openCascadeWebGPU:
      RawWebGPUBenchView(session: session, document: session.document)
    }
  }

  private var statusBar: some View {
    HStack {
      Image(systemName: session.isLoading ? "hourglass" : "info.circle")
      Text(session.status).lineLimit(1)
      Spacer()
      Text("Open CASCADE Technology \(GeomKernel.version)")
      Text("Apple Silicon · local only")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.horizontal, 12)
    .frame(height: 28)
  }

  private func nodeRoots(_ document: GeometryDocument) -> [TreeNode] {
    let all = document.nodes
    func build(_ node: AssemblyNode) -> TreeNode {
      let children = all.filter { $0.parentIndex == node.id }.map(build)
      return TreeNode(id: node.id, name: node.name, children: children.isEmpty ? nil : children)
    }
    return all.filter { $0.parentIndex == nil }.map(build)
  }
}

private struct TreeNode: Identifiable {
  let id: Int
  let name: String
  let children: [TreeNode]?
}

private struct TelemetryHUD: View {
  @Bindable var session: BenchSession

  var body: some View {
    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 5) {
      row("PIPELINE", "P\(session.pipeline.rawValue) · \(session.pipeline.comparisonName)")
      row("ROLE", session.pipeline.role.label)
      row("LOAD", loadText)
      row("FPS", String(format: "%.1f", framesPerSecond))
      row("CPU", String(format: "%.1f %%", session.telemetry.cpuPercent))
      row("MEMORY", String(format: "%.1f MB", memoryMegabytes))
      row("GPU", gpuLabel)
    }
    .font(.system(size: 11, design: .monospaced))
    .padding(12)
    .background(session.theme.panelColor.opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.15)))
    .allowsHitTesting(false)
  }

  private var loadText: String {
    session.telemetry.overrideLoadMilliseconds.map { String(format: "%.1f ms", $0) } ?? "—"
  }

  private var framesPerSecond: Double {
    session.telemetry.framesPerSecond
  }

  private var memoryMegabytes: Double {
    session.telemetry.memoryMegabytes
  }

  private var gpuLabel: String {
    switch session.pipeline {
    case .threeJSWebGPU:
      session.rendererBackend.map { "Three.js via \($0) and Apple WebKit" }
        ?? "Three.js WebGPU probing via Apple WebKit"
    case .openCascadeWebGPU:
      session.rendererBackend.map { "\($0) via Apple WebKit" }
        ?? "Raw WebGPU probing via Apple WebKit"
    default: "Apple Metal / OpenGL"
    }
  }

  private func row(_ label: String, _ value: String) -> some View {
    GridRow {
      Text(label).foregroundStyle(.secondary)
      Text(value).foregroundStyle(.white)
    }
  }
}

private struct NavigationLegend: View {
  var body: some View {
    HStack(spacing: 14) {
      item("RMB", "Orbit / tilt")
      item("MMB", "Pan")
      item("⇧ RMB", "Roll")
      item("Scroll", "Zoom")
      item("⇧ LMB", "Pan")
    }
    .font(.system(size: 10, design: .rounded))
    .padding(.horizontal, 11).padding(.vertical, 7)
    .background(.black.opacity(0.72), in: Capsule())
    .overlay(Capsule().stroke(.white.opacity(0.12)))
    .allowsHitTesting(false)
  }

  private func item(_ input: String, _ action: String) -> some View {
    HStack(spacing: 4) {
      Text(input).fontWeight(.bold).foregroundStyle(.white)
      Text(action).foregroundStyle(.secondary)
    }
  }
}
