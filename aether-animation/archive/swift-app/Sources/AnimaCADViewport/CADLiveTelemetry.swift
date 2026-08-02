import Darwin
import Foundation
import Observation

/// One renderer-performance sample shared by the compact HUD, detailed
/// diagnostics, and Settings. FPS counts frames completed by the active
/// renderer; it is deliberately unrelated to the animation playhead time.
public struct CADViewportPerformanceSnapshot: Equatable, Sendable {
  public var framesPerSecond: Double
  public var cpuPercent: Double
  public var memoryMegabytes: Double

  public init(
    framesPerSecond: Double = 0,
    cpuPercent: Double = 0,
    memoryMegabytes: Double = 0
  ) {
    self.framesPerSecond = framesPerSecond
    self.cpuPercent = cpuPercent
    self.memoryMegabytes = memoryMegabytes
  }

  public static let waiting = Self()

  public var frameTimeMilliseconds: Double? {
    framesPerSecond > 0.01 ? 1_000 / framesPerSecond : nil
  }
}

/// Lightweight live diagnostics imported from Codex Bench. Values describe
/// the Anima Studio process; WebKit content/GPU helper-process cost is not
/// included and is labeled as such in the HUD.
@MainActor @Observable
final class CADLiveTelemetry {
  private(set) var framesPerSecond = 0.0
  private(set) var cpuPercent = 0.0
  private(set) var memoryMegabytes = 0.0
  private var frameCount = 0
  private var timer: Timer?
  private var previousCPUSeconds = processCPUSeconds()
  private var previousDate = Date()
  private var lastExternalFrameSampleDate: Date?
  private var onSample: (@MainActor @Sendable (CADViewportPerformanceSnapshot) -> Void)?

  func start(
    onSample: @escaping @MainActor @Sendable (CADViewportPerformanceSnapshot) -> Void
  ) {
    self.onSample = onSample
    guard timer == nil else {
      publish()
      return
    }
    previousCPUSeconds = Self.processCPUSeconds()
    previousDate = Date()
    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.sample() }
    }
    self.timer = timer
    // Pointer drags run AppKit's event-tracking mode. `.common` keeps the FPS
    // and resource sampler live while the operator orbits or moves a Part.
    RunLoop.main.add(timer, forMode: .common)
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    onSample = nil
  }

  /// Records native per-frame completions or a browser renderer's measured
  /// batch. Supplying the interval avoids aliasing two unrelated one-second
  /// timers into alternating 0/120 FPS readings.
  func recordFrames(_ count: Int = 1, intervalSeconds: Double? = nil) {
    if let intervalSeconds, intervalSeconds > 0 {
      framesPerSecond = Double(max(count, 0)) / intervalSeconds
      lastExternalFrameSampleDate = Date()
      publish()
    } else {
      frameCount += max(count, 0)
    }
  }

  private func sample() {
    let now = Date()
    let elapsed = max(now.timeIntervalSince(previousDate), 0.001)
    if let lastExternalFrameSampleDate {
      if now.timeIntervalSince(lastExternalFrameSampleDate) > 2.5 {
        framesPerSecond = 0
      }
    } else {
      framesPerSecond = Double(frameCount) / elapsed
    }
    frameCount = 0
    let cpu = Self.processCPUSeconds()
    cpuPercent = max(0, (cpu - previousCPUSeconds) / elapsed * 100)
    previousCPUSeconds = cpu
    previousDate = now
    memoryMegabytes = Self.currentMemoryMegabytes()
    publish()
  }

  private func publish() {
    onSample?(
      CADViewportPerformanceSnapshot(
        framesPerSecond: framesPerSecond,
        cpuPercent: cpuPercent,
        memoryMegabytes: memoryMegabytes))
  }

  private static func currentMemoryMegabytes() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1_048_576 : 0
  }

  private static func processCPUSeconds() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
      + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec) / 1_000_000
  }
}
