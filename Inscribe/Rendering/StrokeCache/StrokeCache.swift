import Metal
import Foundation

// MARK: - StrokeCache

/// LRU cache for pre-computed stroke geometry.
///
/// Caching the vertex data for completed strokes avoids regenerating it
/// every frame, dramatically improving rendering performance.
/// The cache uses LRU eviction based on a memory budget.
public class StrokeCache {

    /// Maximum memory usage in bytes (default: 100MB)
    public var maxMemoryBytes: Int {
        didSet { evictIfNeeded() }
    }

    /// Current memory usage in bytes
    public private(set) var memoryUsage: Int = 0

    private var cache: [UUID: CacheEntry] = [:]
    private var accessOrder: [UUID] = []

    // MARK: - Initialization

    public init(maxMemoryMB: Int = 100) {
        self.maxMemoryBytes = maxMemoryMB * 1024 * 1024
    }

    // MARK: - Public API

    /// Cache a stroke's geometry.
    public func cache(_ geometry: MetalStrokeGeometry, for strokeID: UUID) {
        let entry = CacheEntry(geometry: geometry)
        let newSize = geometry.sizeInBytes

        // Remove old entry if exists
        if let oldEntry = cache[strokeID] {
            memoryUsage -= oldEntry.geometry.sizeInBytes
            accessOrder.removeAll { $0 == strokeID }
        }

        cache[strokeID] = entry
        accessOrder.append(strokeID)
        memoryUsage += newSize

        evictIfNeeded()
    }

    /// Retrieve cached geometry for a stroke.
    public func cachedGeometry(for strokeID: UUID) -> MetalStrokeGeometry? {
        guard let entry = cache[strokeID] else { return nil }

        // Move to end of access order (most recently used)
        accessOrder.removeAll { $0 == strokeID }
        accessOrder.append(strokeID)

        return entry.geometry
    }

    /// Remove a specific stroke from cache.
    public func removeCachedGeometry(for strokeID: UUID) {
        guard let entry = cache.removeValue(forKey: strokeID) else { return }
        memoryUsage -= entry.geometry.sizeInBytes
        accessOrder.removeAll { $0 == strokeID }
    }

    /// Remove all cached geometry.
    public func removeAll() {
        cache.removeAll()
        accessOrder.removeAll()
        memoryUsage = 0
    }

    /// The number of cached strokes.
    public var count: Int { cache.count }

    // MARK: - Private

    private func evictIfNeeded() {
        while memoryUsage > maxMemoryBytes && accessOrder.count > 1 {
            let oldestID = accessOrder.removeFirst()
            if let entry = cache.removeValue(forKey: oldestID) {
                memoryUsage -= entry.geometry.sizeInBytes
            }
        }
    }
}

// MARK: - CacheEntry

private struct CacheEntry {
    let geometry: MetalStrokeGeometry
    let cachedAt: Date

    init(geometry: MetalStrokeGeometry) {
        self.geometry = geometry
        self.cachedAt = Date()
    }
}

// MARK: - MetalStrokeGeometry

/// Pre-computed Metal geometry for a stroke.
public struct MetalStrokeGeometry {
    public let vertexBuffer: MTLBuffer
    public let vertexCount: Int
    public let bounds: CGRect

    public var sizeInBytes: Int {
        vertexBuffer.length
    }
}
