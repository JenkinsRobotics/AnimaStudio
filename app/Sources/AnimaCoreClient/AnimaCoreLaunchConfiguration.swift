import Foundation

public struct AnimaCoreLaunchConfiguration: Equatable, Sendable {
  public let executableURL: URL
  public let arguments: [String]
  public let currentDirectoryURL: URL?
  public let environment: [String: String]?

  public init(
    executableURL: URL,
    arguments: [String],
    currentDirectoryURL: URL? = nil,
    environment: [String: String]? = nil
  ) {
    self.executableURL = executableURL
    self.arguments = arguments
    self.currentDirectoryURL = currentDirectoryURL
    self.environment = environment
  }

  public static func python(
    executableURL: URL,
    repositoryRootURL: URL,
    environment: [String: String]? = nil
  ) -> Self {
    Self(
      executableURL: executableURL,
      arguments: ["-m", "animacore.bridge"],
      currentDirectoryURL: repositoryRootURL,
      environment: environment
    )
  }

  public static func resolved(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    currentDirectoryURL: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
    bundleURL: URL = Bundle.main.bundleURL,
    fileManager: FileManager = .default
  ) throws -> Self {
    if let explicitPath = environment["ANIMACORE_HELPER_EXECUTABLE"],
      fileManager.isExecutableFile(atPath: explicitPath)
    {
      return Self(
        executableURL: URL(fileURLWithPath: explicitPath),
        arguments: [],
        environment: environment
      )
    }

    let bundledHelper =
      bundleURL
      .appendingPathComponent("Contents", isDirectory: true)
      .appendingPathComponent("Helpers", isDirectory: true)
      .appendingPathComponent("animacore-bridge")
    if fileManager.isExecutableFile(atPath: bundledHelper.path) {
      return Self(
        executableURL: bundledHelper,
        arguments: [],
        environment: environment
      )
    }

    let bundledPython =
      bundleURL
      .appendingPathComponent("Contents", isDirectory: true)
      .appendingPathComponent("Helpers", isDirectory: true)
      .appendingPathComponent("animacore-python")
    let bundledPythonHome =
      bundleURL
      .appendingPathComponent("Contents", isDirectory: true)
      .appendingPathComponent("Frameworks", isDirectory: true)
      .appendingPathComponent("Python.framework", isDirectory: true)
      .appendingPathComponent("Versions", isDirectory: true)
      .appendingPathComponent("Current", isDirectory: true)
    let bundledPythonPath =
      bundleURL
      .appendingPathComponent("Contents", isDirectory: true)
      .appendingPathComponent("Resources", isDirectory: true)
      .appendingPathComponent("AnimaCorePython", isDirectory: true)
    if fileManager.isExecutableFile(atPath: bundledPython.path),
      fileManager.fileExists(atPath: bundledPythonHome.path),
      fileManager.fileExists(atPath: bundledPythonPath.path)
    {
      var bundledEnvironment = environment
      bundledEnvironment["PYTHONHOME"] = bundledPythonHome.path
      bundledEnvironment["PYTHONPATH"] = bundledPythonPath.path
      bundledEnvironment["PYTHONNOUSERSITE"] = "1"
      return Self(
        executableURL: bundledPython,
        arguments: ["-m", "animacore.bridge"],
        currentDirectoryURL: bundledPythonPath,
        environment: bundledEnvironment
      )
    }

    var startingPoints = [
      currentDirectoryURL,
      bundleURL.deletingLastPathComponent(),
    ]
    if let repositoryRootPath = environment["ANIMACORE_REPOSITORY_ROOT"] {
      startingPoints.insert(URL(fileURLWithPath: repositoryRootPath), at: 0)
    }
    for startingPoint in startingPoints {
      guard
        let repositoryRoot = findRepositoryRoot(
          from: startingPoint,
          fileManager: fileManager
        )
      else { continue }

      let virtualEnvironmentPython =
        repositoryRoot
        .appendingPathComponent(".venv", isDirectory: true)
        .appendingPathComponent("bin", isDirectory: true)
        .appendingPathComponent("python")
      if fileManager.isExecutableFile(atPath: virtualEnvironmentPython.path) {
        return .python(
          executableURL: virtualEnvironmentPython,
          repositoryRootURL: repositoryRoot,
          environment: environment
        )
      }
    }

    throw AnimaCoreClientError.helperNotFound
  }

  private static func findRepositoryRoot(
    from startingURL: URL,
    fileManager: FileManager
  ) -> URL? {
    var candidate = startingURL.standardizedFileURL
    for _ in 0..<8 {
      let bridge =
        candidate
        .appendingPathComponent("animacore", isDirectory: true)
        .appendingPathComponent("bridge.py")
      if fileManager.fileExists(atPath: bridge.path) {
        return candidate
      }
      let parent = candidate.deletingLastPathComponent()
      guard parent != candidate else { break }
      candidate = parent
    }
    return nil
  }
}
