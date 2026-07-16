import AnimaCoreClient
import Foundation
import Testing

@Suite(.serialized)
struct AnimaCoreClientTests {
  @Test
  func liveBridgeHandshakeLoadEvaluateReleaseAndShutdown() async throws {
    let repositoryRoot = try repositoryRootURL()
    let python = repositoryRoot.appendingPathComponent(".venv/bin/python")
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: python,
        repositoryRootURL: repositoryRoot
      )
    )

    let hello = try await client.start()
    #expect(hello.engine == "animacore")
    #expect(hello.protocolVersion == 1)
    #expect(hello.capabilities.contains("evaluate"))
    #expect(hello.capabilities.contains("mate_types"))

    let mateCatalog = try await client.mateTypes()
    #expect(
      Set(mateCatalog.mateTypes.map(\.type)).isSuperset(
        of: [
          "fastened", "parallel", "prismatic", "revolute",
          "cylindrical", "pin_slot", "planar", "ball",
        ]
      )
    )
    let fastenedType = try #require(
      mateCatalog.mateTypes.first { $0.type == "fastened" }
    )
    #expect(fastenedType.label == "Fastened")
    #expect(fastenedType.degreeOfFreedomCount == 0)
    #expect(fastenedType.degreesOfFreedom.isEmpty)
    #expect(
      fastenedType.universalControls == [
        "connector_a",
        "connector_b",
        "offset",
        "flip_primary_axis",
        "secondary_axis_rotation",
        "simulation_connection",
      ]
    )

    let characterURL =
      repositoryRoot
      .appendingPathComponent("examples/six_axis_arm.character.anima")
    let text = try String(contentsOf: characterURL, encoding: .utf8)
    let loaded = try await client.loadCharacter(text: text)
    #expect(loaded.handle == "rig1")
    #expect(loaded.rig.identity.name == "six_axis_arm")
    #expect(loaded.rig.joints.count == 6)
    let baseYaw = try #require(loaded.rig.joints.first)
    #expect(baseYaw.id == "Revolute 1")
    #expect(baseYaw.parentPart == "base")
    #expect(baseYaw.childPart == "shoulder")
    #expect(baseYaw.controls.connectors.a?.feature == "base/top_face")
    #expect(baseYaw.controls.offset.translationMeters == [0, 0, 0.012])
    #expect(baseYaw.controls.offset.rotationAxis == .z)
    #expect(abs(baseYaw.controls.offset.rotationRadians - .pi / 120) < 1e-12)

    let evaluation = try await client.evaluate(
      handle: loaded.handle,
      clip: "pick",
      timeSeconds: 1
    )
    #expect(evaluation.degreesOfFreedom["base_yaw.rotation"] == .pi / 3)
    #expect(evaluation.channelsByIndex.keys.sorted() == [0, 1, 2, 3, 4, 5])
    #expect(evaluation.limitViolations.isEmpty)

    try await client.release(handle: loaded.handle)
    await client.shutdown()
  }

  @Test
  func fastenedMateUsesStableIdentityAndUniversalControls() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    defer { Task { await client.shutdown() } }

    let text = """
      anima_version: "2.0"
      type: character
      identity: { name: fastened_fixture, display_name: "Fastened Fixture" }
      parts:
        base: {}
        lid: { parent: base }
      joints:
        fixed_lid:
          type: fastened
          id: "Fastened 33"
          parent: base
          child: lid
          connectors:
            a:
              part: base
              origin_m: [0.0, 0.0, 0.025]
              primary_axis: [0.0, 0.0, 1.0]
              secondary_axis: [1.0, 0.0, 0.0]
              feature: "base/top_face"
            b:
              part: lid
              origin_m: [0.0, 0.0, -0.004]
              primary_axis: [0.0, 0.0, 1.0]
              secondary_axis: [1.0, 0.0, 0.0]
              flipped: true
              feature: "lid/bottom_face"
          offset:
            enabled: true
            translation_m: [0.001, 0.002, 0.003]
            rotate_about: x
            angle_deg: 15
          flip_primary_axis: true
          secondary_axis_rotation_deg: 90
          simulation_connection: false
      """

    let loaded = try await client.loadCharacter(text: text)
    let mate = try #require(loaded.rig.joints.first)
    #expect(mate.id == "Fastened 33")
    #expect(mate.selectionKey == "Fastened 33")
    #expect(mate.name == "fixed_lid")
    #expect(mate.type == "fastened")
    #expect(mate.degreesOfFreedom.isEmpty)
    #expect(mate.controls.connectors.a?.part == "base")
    #expect(mate.controls.connectors.b?.isFlipped == true)
    #expect(mate.controls.offset.translationMeters == [0.001, 0.002, 0.003])
    #expect(mate.controls.offset.rotationAxis == .x)
    #expect(abs(mate.controls.offset.rotationRadians - .pi / 12) < 1e-12)
    #expect(mate.controls.flipsPrimaryAxis)
    #expect(mate.controls.secondaryAxisRotationDegrees == 90)
    #expect(!mate.controls.isSimulationConnection)
  }

  @Test
  func formatErrorPreservesEnginePath() async throws {
    let repositoryRoot = try repositoryRootURL()
    let client = AnimaCoreClient(
      configuration: .python(
        executableURL: repositoryRoot.appendingPathComponent(".venv/bin/python"),
        repositoryRootURL: repositoryRoot
      )
    )
    defer { Task { await client.shutdown() } }

    let broken = """
      anima_version: "2.0"
      type: character
      identity: { name: broken }
      parts: { a: {}, b: { parent: a } }
      joints:
        bad:
          type: not_a_joint
          parent: a
          child: b
          dofs: {}
      """

    do {
      _ = try await client.loadCharacter(text: broken)
      Issue.record("Expected the engine to reject the invalid mate type")
    } catch let AnimaCoreClientError.remote(error) {
      #expect(error.code == "format_error")
      #expect(error.path == "joints.bad.type")
      #expect(error.errorDescription?.contains("joints.bad.type") == true)
    }
  }

  @Test
  func launchResolverFindsRepositoryVirtualEnvironment() throws {
    let appDirectory = try repositoryRootURL().appendingPathComponent("app")
    let configuration = try AnimaCoreLaunchConfiguration.resolved(
      environment: [:],
      currentDirectoryURL: appDirectory,
      bundleURL: appDirectory
    )

    #expect(configuration.executableURL.lastPathComponent == "python")
    #expect(configuration.arguments == ["-m", "animacore.bridge"])
    #expect(configuration.currentDirectoryURL == appDirectory.deletingLastPathComponent())
  }

  @Test
  func launchResolverPrefersBundledPythonRuntime() throws {
    let temporaryRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bundle = temporaryRoot.appendingPathComponent("Anima Studio.app", isDirectory: true)
    let helper = bundle.appendingPathComponent("Contents/Helpers/animacore-python")
    let pythonHome =
      bundle.appendingPathComponent("Contents/Frameworks/Python.framework/Versions/Current")
    let pythonPath = bundle.appendingPathComponent("Contents/Resources/AnimaCorePython")
    defer { try? FileManager.default.removeItem(at: temporaryRoot) }

    try FileManager.default.createDirectory(
      at: helper.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(at: pythonHome, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: pythonPath, withIntermediateDirectories: true)
    try FileManager.default.copyItem(at: URL(fileURLWithPath: "/bin/sh"), to: helper)

    let configuration = try AnimaCoreLaunchConfiguration.resolved(
      environment: ["ANIMA_TEST": "yes"],
      currentDirectoryURL: temporaryRoot,
      bundleURL: bundle
    )

    #expect(configuration.executableURL == helper)
    #expect(configuration.arguments == ["-m", "animacore.bridge"])
    #expect(configuration.currentDirectoryURL?.path == pythonPath.path)
    #expect(configuration.environment?["PYTHONHOME"] == pythonHome.path)
    #expect(configuration.environment?["PYTHONPATH"] == pythonPath.path)
    #expect(configuration.environment?["PYTHONNOUSERSITE"] == "1")
    #expect(configuration.environment?["ANIMA_TEST"] == "yes")
  }

  private func repositoryRootURL() throws -> URL {
    var candidate = URL(fileURLWithPath: #filePath)
    for _ in 0..<8 {
      candidate.deleteLastPathComponent()
      if FileManager.default.fileExists(
        atPath: candidate.appendingPathComponent("animacore/bridge.py").path
      ) {
        return candidate
      }
    }
    throw AnimaCoreClientError.helperNotFound
  }
}
