import Foundation
import QuartzCore
import UIKit

// MARK: - PerformanceMetrics

/// Current performance metrics snapshot.
public struct PerformanceMetrics: Sendable {
    public let fps: Double
    public let memoryUsageMB: Double
    public let cpuUsage: Double
    public let frameDrops: Int
    public let gpuUtilization: Double?
}

// MARK: - PerformanceMonitor

/// Monitors app performance including FPS, memory, and CPU usage.
public class PerformanceMonitor {

    public var isEnabled: Bool = false

    /// Called every sampling interval with current metrics
    public var onMetricsUpdate: ((PerformanceMetrics) -> Void)?

    private var displayLink: CADisplayLink?
    private var frameTimestamps: [CFTimeInterval] = []
    private var frameDropCount: Int = 0
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var timer: Timer?

    // MARK: - Public API

    public func start() {
        guard !isEnabled else { return }
        isEnabled = true
        frameDropCount = 0

        displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        displayLink?.add(to: .main, forMode: .common)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.reportMetrics()
        }
    }

    public func stop() {
        isEnabled = false
        displayLink?.invalidate()
        displayLink = nil
        timer?.invalidate()
        timer = nil
        frameTimestamps.removeAll()
    }

    public func recordFrameDrop() {
        frameDropCount += 1
    }

    // MARK: - Frame Tracking

    @objc private func frameUpdate(link: CADisplayLink) {
        let timestamp = link.timestamp
        frameTimestamps.append(timestamp)

        // Keep only the last 60 timestamps (1 second at 60fps)
        if frameTimestamps.count > 60 {
            frameTimestamps.removeFirst()
        }

        if lastFrameTimestamp > 0 {
            let delta = timestamp - lastFrameTimestamp
            let expectedDelta = 1.0 / Double(max(link.preferredFramesPerSecond, 60))
            if delta > expectedDelta * 1.5 {
                frameDropCount += 1
            }
        }

        lastFrameTimestamp = timestamp
    }

    private func reportMetrics() {
        guard isEnabled else { return }

        let fps = calculateFPS()
        let memory = memoryUsage()
        let cpu = cpuUsage()

        let metrics = PerformanceMetrics(
            fps: fps,
            memoryUsageMB: memory,
            cpuUsage: cpu,
            frameDrops: frameDropCount,
            gpuUtilization: nil // Requires Metal device query
        )

        onMetricsUpdate?(metrics)
        frameDropCount = 0
    }

    private func calculateFPS() -> Double {
        guard frameTimestamps.count >= 2 else { return 0 }
        let elapsed = frameTimestamps.last! - frameTimestamps.first!
        guard elapsed > 0 else { return 0 }
        return Double(frameTimestamps.count - 1) / elapsed
    }

    // MARK: - System Metrics

    private func memoryUsage() -> Double {
        var info = task_vm_info_data_t()
        var size = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &size)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        let usedBytes = info.phys_footprint
        return Double(usedBytes) / (1024 * 1024)
    }

    private func cpuUsage() -> Double {
        var threadsList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let result = task_threads(mach_task_self_, &threadsList, &threadCount)

        guard result == KERN_SUCCESS, let threads = threadsList else { return 0 }

        var totalCPU: Double = 0
        for i in 0..<Int(threadCount) {
            var threadInfo = thread_basic_info()
            var count = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)

            let kr = withUnsafeMutablePointer(to: &threadInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }

            guard kr == KERN_SUCCESS else { continue }

            let info = threadInfo as thread_basic_info
            if info.flags & TH_FLAGS_IDLE == 0 {
                totalCPU += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
        }

        vm_deallocate(mach_task_self_,
                     vm_address_t(UInt(bitPattern: threadsList)),
                     vm_size_t(threadCount) * vm_size_t(MemoryLayout<thread_t>.stride))

        return totalCPU
    }
}
