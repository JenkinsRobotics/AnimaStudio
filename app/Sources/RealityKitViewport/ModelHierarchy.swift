import Foundation
import RealityKit

public struct ModelEntityPathComponent: Hashable, Sendable {
  public let name: String
  public let siblingIndex: Int

  public init(name: String, siblingIndex: Int) {
    self.name = name
    self.siblingIndex = siblingIndex
  }

  public var displayName: String {
    name.isEmpty ? "Unnamed Entity" : name
  }
}

public struct ModelEntityPath: Hashable, Sendable {
  public let components: [ModelEntityPathComponent]

  public init(components: [ModelEntityPathComponent]) {
    precondition(!components.isEmpty)
    self.components = components
  }

  public var displayString: String {
    components
      .map { "\($0.displayName)[\($0.siblingIndex)]" }
      .joined(separator: " / ")
  }

  /// Opaque node path written to AnimaCore's `model_node` field.
  public var modelNodeReference: String {
    components.map(\.name).filter { !$0.isEmpty }.joined(separator: "/")
  }

  fileprivate func appending(
    name: String,
    siblingIndex: Int
  ) -> ModelEntityPath {
    ModelEntityPath(
      components: components + [
        ModelEntityPathComponent(name: name, siblingIndex: siblingIndex)
      ]
    )
  }
}

public struct ModelHierarchyNode: Identifiable, Equatable, Sendable {
  public let id: ModelEntityPath
  public let name: String
  public let children: [ModelHierarchyNode]

  public init(
    id: ModelEntityPath,
    name: String,
    children: [ModelHierarchyNode]
  ) {
    self.id = id
    self.name = name
    self.children = children
  }

  public var displayName: String {
    name.isEmpty ? "Unnamed Entity" : name
  }

  public var outlineChildren: [ModelHierarchyNode]? {
    children.isEmpty ? nil : children
  }

  public var nodeCount: Int {
    1 + children.reduce(0) { $0 + $1.nodeCount }
  }

  public var flattened: [ModelHierarchyNode] {
    [self] + children.flatMap(\.flattened)
  }

  public func node(at path: ModelEntityPath) -> ModelHierarchyNode? {
    guard id != path else { return self }
    return children.lazy.compactMap { $0.node(at: path) }.first
  }
}

@MainActor
public enum RealityKitModelHierarchy {
  public static func load(
    contentsOf url: URL,
    unitScaleToMeters: Double = 1
  ) async throws -> ModelHierarchyNode {
    let entity = try await RealityKitModelLoader.load(
      contentsOf: url,
      unitScaleToMeters: unitScaleToMeters
    )
    return inspect(entity)
  }

  public static func inspect(_ root: Entity) -> ModelHierarchyNode {
    let rootPath = ModelEntityPath(
      components: [
        ModelEntityPathComponent(name: root.name, siblingIndex: 0)
      ]
    )
    return inspect(root, path: rootPath)
  }

  private static func inspect(
    _ entity: Entity,
    path: ModelEntityPath
  ) -> ModelHierarchyNode {
    let children = Array(entity.children).enumerated().map { index, child in
      inspect(
        child,
        path: path.appending(name: child.name, siblingIndex: index)
      )
    }
    return ModelHierarchyNode(id: path, name: entity.name, children: children)
  }
}
