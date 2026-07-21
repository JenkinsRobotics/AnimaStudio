import Darwin
import Foundation
import Observation

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

  func start() {
    guard timer == nil else { return }
    previousCPUSeconds = Self.processCPUSeconds()
    previousDate = Date()
    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      Task { @MainActor in self?.sample() }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
  }

  func recordFrames(_ count: Int = 1) { frameCount += count }

  private func sample() {
    let now = Date()
    let elapsed = max(now.timeIntervalSince(previousDate), 0.001)
    framesPerSecond = Double(frameCount) / elapsed
    frameCount = 0
    let cpu = Self.processCPUSeconds()
    cpuPercent = max(0, (cpu - previousCPUSeconds) / elapsed * 100)
    previousCPUSeconds = cpu
    previousDate = now
    memoryMegabytes = Self.currentMemoryMegabytes()
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
