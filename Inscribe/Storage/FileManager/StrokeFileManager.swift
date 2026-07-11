import Foundation
import OSLog
import InscribeCore

// MARK: - StrokeFileManager

/// Handles reading and writing stroke data using the custom binary format.
///
/// The binary format is designed for:
/// - Fast serialization/deserialization
/// - Memory-mappable for instant access
/// - Minimal file size (10-20x smaller than JSON)
/// - Forward compatibility via version field
///
/// Format specification (see architecture.md §6.1):
/// ┌─────────────────────────────────┐
/// │ Header (32 bytes)               │
/// │ - Magic number: 0x494E4B52     │
/// │ - Version: UInt16               │
/// │ - Stroke count: UInt32          │
/// │ - Total points: UInt32          │
/// ├─────────────────────────────────┤
/// │ Stroke 1                        │
/// │ ├── Metadata (56 bytes)         │
/// │ └── Point Data (N * 20 bytes)   │
/// ├─────────────────────────────────┤
/// │ Stroke 2...                     │
/// └─────────────────────────────────┘
public actor StrokeFileManager {

    public static let shared = StrokeFileManager()

    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.inscribe.storage", category: "StrokeFileManager")

    /// File extension for stroke data files
    public static let fileExtension = ".inkstroke"

    /// Current binary format version
    public static let currentVersion: UInt16 = 1

    /// Magic number for format validation ("INKR" in ASCII)
    public static let magicNumber: UInt32 = 0x494E4B52

    // MARK: - Directory Management

    /// Root directory for stroke data files
    private var strokeRootDirectory: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("strokes", isDirectory: true)
    }

    /// Ensure the stroke directory exists
    private func ensureDirectoryExists() throws {
        let dir = strokeRootDirectory
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(
                at: dir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// File URL for a specific page's stroke data
    private func fileURL(for pageID: UUID) -> URL {
        strokeRootDirectory.appendingPathComponent("\(pageID.uuidString)\(Self.fileExtension)")
    }

    // MARK: - Writing

    /// Save strokes for a page to disk.
    /// - Parameters:
    ///   - strokes: The strokes to save
    ///   - pageID: The page these strokes belong to
    public func saveStrokes(_ strokes: [Stroke], pageID: UUID) async throws {
        try ensureDirectoryExists()
        let data = try encodeStrokes(strokes)
        let url = fileURL(for: pageID)
        try data.write(to: url, options: Data.WritingOptions.atomic)
        logger.debug("Saved \(strokes.count) strokes for page \(pageID)")
    }

    /// Append strokes to an existing page file.
    /// - Parameters:
    ///   - strokes: New strokes to append
    ///   - pageID: The page these strokes belong to
    public func appendStrokes(_ strokes: [Stroke], pageID: UUID) async throws {
        let existing = try? loadStrokes(pageID: pageID)
        let allStrokes = (existing ?? []) + strokes
        try await saveStrokes(allStrokes, pageID: pageID)
    }

    // MARK: - Reading

    /// Load all strokes for a page.
    /// - Parameter pageID: The page to load strokes for
    /// - Returns: Array of decoded strokes
    public func loadStrokes(pageID: UUID) throws -> [Stroke] {
        let url = fileURL(for: pageID)
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try decodeStrokes(from: data)
    }

    /// Load stroke metadata (without full point data) for a page.
    /// Useful for displaying stroke counts without loading everything.
    /// - Parameter pageID: The page to get metadata for
    /// - Returns: Array of stroke metadata entries
    public func loadStrokeMetadata(pageID: UUID) throws -> [StrokeMetadataModel] {
        let url = fileURL(for: pageID)
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try decodeMetadataOnly(from: data)
    }

    /// Check if stroke data exists for a page
    public func hasStrokeData(pageID: UUID) -> Bool {
        let url = fileURL(for: pageID)
        return fileManager.fileExists(atPath: url.path)
    }

    /// Get the file size for a page's stroke data
    public func strokeDataSize(pageID: UUID) -> UInt64 {
        let url = fileURL(for: pageID)
        guard let attrs = try? fileManager.attributesOfItem(atPath: url.path) else {
            return 0
        }
        return attrs[.size] as? UInt64 ?? 0
    }

    // MARK: - Deletion

    /// Delete all strokes for a page.
    public func deleteStrokes(pageID: UUID) throws {
        let url = fileURL(for: pageID)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
            logger.debug("Deleted strokes for page \(pageID)")
        }
    }

    /// Delete a specific stroke from a page's data.
    /// This requires rewriting the file without the deleted stroke.
    public func deleteStroke(strokeID: UUID, pageID: UUID) async throws {
        var strokes = try loadStrokes(pageID: pageID)
        strokes.removeAll { $0.id == strokeID }
        try await saveStrokes(strokes, pageID: pageID)
    }

    // MARK: - Binary Encoding

    /// Encode strokes to the custom binary format.
    /// Format:
    /// [Magic:4][Version:2][StrokeCount:4][TotalPoints:4]
    /// For each stroke:
    ///   [ID:16][ToolType:1][ColorRGBA:4][Width:4][PointCount:4][Flags:2]
    ///   For each point:
    ///     [X:4][Y:4][Pressure:4][Azimuth:4][Altitude:4][Roll?:4]
    private func encodeStrokes(_ strokes: [Stroke]) throws -> Data {
        var data = Data()

        // Count total points
        let totalPoints = strokes.reduce(0) { $0 + $1.pointCount }

        // Header
        data.append(encodeUInt32(Self.magicNumber))
        data.append(encodeUInt16(Self.currentVersion))
        data.append(encodeUInt32(UInt32(strokes.count)))
        data.append(encodeUInt32(UInt32(totalPoints)))

        // Stroke data
        for stroke in strokes {
            try encodeStroke(stroke, to: &data)
        }

        return data
    }

    private func encodeStroke(_ stroke: Stroke, to data: inout Data) throws {
        // Stroke ID (16 bytes)
        withUnsafeBytes(of: stroke.id.uuid) { ptr in
            data.append(contentsOf: ptr)
        }

        // Tool type (1 byte)
        data.append(UInt8(stroke.toolType.rawValue.hashValue & 0xFF))

        // Color RGBA (4 bytes)
        data.append(encodeUInt32(stroke.color.rgbaUInt32))

        // Width (4 bytes)
        data.append(encodeFloat32(Float(stroke.width)))

        // Point count (4 bytes)
        let pointCount = UInt32(stroke.points.count)
        data.append(encodeUInt32(pointCount))

        // Flags (2 bytes): bit 0 = hasRoll
        let hasRoll: UInt16 = stroke.points.contains(where: { $0.roll != nil }) ? 1 : 0
        data.append(encodeUInt16(hasRoll))

        // Point data
        for point in stroke.points {
            encodePoint(point, to: &data, includeRoll: hasRoll == 1)
        }
    }

    private func encodePoint(_ point: InkPoint, to data: inout Data, includeRoll: Bool) {
        data.append(encodeFloat32(Float(point.location.x)))
        data.append(encodeFloat32(Float(point.location.y)))
        data.append(encodeFloat32(Float(point.pressure)))
        data.append(encodeFloat32(Float(point.azimuth)))
        data.append(encodeFloat32(Float(point.altitude)))
        if includeRoll, let roll = point.roll {
            data.append(encodeFloat32(Float(roll)))
        }
    }

    // MARK: - Binary Decoding

    private func decodeStrokes(from data: Data) throws -> [Stroke] {
        var offset = 0

        // Read header
        let magic = try readUInt32(from: data, at: &offset)
        guard magic == Self.magicNumber else {
            throw StrokeFileError.invalidMagicNumber
        }

        let _ = try readUInt16(from: data, at: &offset) // version
        let strokeCount = Int(try readUInt32(from: data, at: &offset))
        let _ = try readUInt32(from: data, at: &offset) // total points (unused here)

        var strokes: [Stroke] = []
        for _ in 0..<strokeCount {
            let stroke = try decodeStroke(from: data, at: &offset)
            strokes.append(stroke)
        }

        return strokes
    }

    private func decodeMetadataOnly(from data: Data) throws -> [StrokeMetadataModel] {
        var offset = 0

        let magic = try readUInt32(from: data, at: &offset)
        guard magic == Self.magicNumber else {
            throw StrokeFileError.invalidMagicNumber
        }

        let _ = try readUInt16(from: data, at: &offset) // version
        let strokeCount = Int(try readUInt32(from: data, at: &offset))
        let _ = try readUInt32(from: data, at: &offset) // total points

        var metadataList: [StrokeMetadataModel] = []
        for _ in 0..<strokeCount {
            // Read stroke ID
            let id = try readUUID(from: data, at: &offset)

            // Tool type
            let toolTypeRaw = data[offset]; offset += 1

            // Color
            let colorRGBA = try readUInt32(from: data, at: &offset)
            let color = PlatformColor.from(rgba: colorRGBA)

            // Width
            let width = CGFloat(try readFloat32(from: data, at: &offset))

            // Point count (skip points for metadata only)
            let pointCount = Int(try readUInt32(from: data, at: &offset))

            // Flags
            let flags = try readUInt16(from: data, at: &offset)
            let hasRoll = (flags & 1) == 1

            // Skip point data
            let pointSize = hasRoll ? 24 : 20 // 5 or 6 floats * 4 bytes
            offset += pointSize * pointCount

            metadataList.append(StrokeMetadataModel(
                id: id,
                pageID: UUID(), // caller must set
                toolTypeRaw: toolTypeRaw,
                color: color,
                width: width,
                pointCount: pointCount,
                hasRoll: hasRoll
            ))
        }

        return metadataList
    }

    private func decodeStroke(from data: Data, at offset: inout Int) throws -> Stroke {
        // Stroke ID
        let id = try readUUID(from: data, at: &offset)

        // Tool type
        let toolTypeRaw = data[offset]; offset += 1
        let toolType: ToolType
        switch toolTypeRaw {
        case 0...8:
            toolType = ToolType.allCases[Int(toolTypeRaw)]
        default:
            toolType = .fountainPen
        }

        // Color
        let colorRGBA = try readUInt32(from: data, at: &offset)
        let color = PlatformColor.from(rgba: colorRGBA)

        // Width
        let width = CGFloat(try readFloat32(from: data, at: &offset))

        // Point count
        let pointCount = Int(try readUInt32(from: data, at: &offset))

        // Flags
        let flags = try readUInt16(from: data, at: &offset)
        let hasRoll = (flags & 1) == 1

        // Points
        var points: [InkPoint] = []
        points.reserveCapacity(pointCount)

        for _ in 0..<pointCount {
            let point = try decodePoint(from: data, at: &offset, hasRoll: hasRoll)
            points.append(point)
        }

        return Stroke(
            id: id,
            points: points,
            toolType: toolType,
            color: color,
            width: width,
            creationDate: Date() // timestamp not stored in binary format
        )
    }

    private func decodePoint(from data: Data, at offset: inout Int, hasRoll: Bool) throws -> InkPoint {
        let x = CGFloat(try readFloat32(from: data, at: &offset))
        let y = CGFloat(try readFloat32(from: data, at: &offset))
        let pressure = CGFloat(try readFloat32(from: data, at: &offset))
        let azimuth = CGFloat(try readFloat32(from: data, at: &offset))
        let altitude = CGFloat(try readFloat32(from: data, at: &offset))

        let roll: CGFloat?
        if hasRoll {
            roll = CGFloat(try readFloat32(from: data, at: &offset))
        } else {
            roll = nil
        }

        return InkPoint(
            location: CGPoint(x: x, y: y),
            pressure: pressure,
            azimuth: azimuth,
            altitude: altitude,
            roll: roll,
            velocity: 0, // not stored; recalculated on load
            timestamp: 0  // not stored in v1 format
        )
    }

    // MARK: - Primitive Encoding

    private func encodeUInt32(_ value: UInt32) -> Data {
        var val = CFSwapInt32HostToBig(value)
        return Data(bytes: &val, count: MemoryLayout<UInt32>.size)
    }

    private func encodeUInt16(_ value: UInt16) -> Data {
        var val = CFSwapInt16HostToBig(value)
        return Data(bytes: &val, count: MemoryLayout<UInt16>.size)
    }

    private func encodeFloat32(_ value: Float) -> Data {
        var val = value
        return Data(bytes: &val, count: MemoryLayout<Float>.size)
    }

    // MARK: - Primitive Decoding

    private func readUInt32(from data: Data, at offset: inout Int) throws -> UInt32 {
        guard offset + 4 <= data.count else { throw StrokeFileError.truncatedData }
        let value = data.withUnsafeBytes { ptr in
            CFSwapInt32BigToHost(ptr.load(fromByteOffset: offset, as: UInt32.self))
        }
        offset += 4
        return value
    }

    private func readUInt16(from data: Data, at offset: inout Int) throws -> UInt16 {
        guard offset + 2 <= data.count else { throw StrokeFileError.truncatedData }
        let value = data.withUnsafeBytes { ptr in
            CFSwapInt16BigToHost(ptr.load(fromByteOffset: offset, as: UInt16.self))
        }
        offset += 2
        return value
    }

    private func readFloat32(from data: Data, at offset: inout Int) throws -> Float {
        guard offset + 4 <= data.count else { throw StrokeFileError.truncatedData }
        let value = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: Float.self)
        }
        offset += 4
        return value
    }

    private func readUUID(from data: Data, at offset: inout Int) throws -> UUID {
        guard offset + 16 <= data.count else { throw StrokeFileError.truncatedData }
        let uuid = data.withUnsafeBytes { ptr in
            ptr.load(fromByteOffset: offset, as: uuid_t.self)
        }
        offset += 16
        return UUID(uuid: uuid)
    }
}

// MARK: - StrokeMetadataModel

/// Lightweight metadata for a stroke (without full point data).
public struct StrokeMetadataModel: Identifiable, Sendable {
    public let id: UUID
    public let pageID: UUID
    public let toolTypeRaw: UInt8
    public let color: PlatformColor
    public let width: CGFloat
    public let pointCount: Int
    public let hasRoll: Bool

    public var toolType: ToolType? {
        let index = Int(toolTypeRaw)
        guard index >= 0, index < ToolType.allCases.count else { return nil }
        return ToolType.allCases[index]
    }
}

// MARK: - StrokeFileError

public enum StrokeFileError: Error, LocalizedError {
    case invalidMagicNumber
    case truncatedData
    case unsupportedVersion
    case fileNotFound

    public var errorDescription: String? {
        switch self {
        case .invalidMagicNumber:
            return "File is not a valid Inscribe stroke file"
        case .truncatedData:
            return "Stroke file is corrupt or truncated"
        case .unsupportedVersion:
            return "Stroke file uses an unsupported format version"
        case .fileNotFound:
            return "Stroke file not found"
        }
    }
}
