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

    let characterURL =
      repositoryRoot
      .appendingPathComponent("examples/six_axis_arm.character.anima")
    let text = try String(contentsOf: characterURL, encoding: .utf8)
    let loaded = try await client.loadCharacter(text: text)
    #expect(loaded.handle == "rig1")
    #expect(loaded.rig.identity.name == "six_axis_arm")
    #expect(loaded.rig.joints.count == 6)

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
