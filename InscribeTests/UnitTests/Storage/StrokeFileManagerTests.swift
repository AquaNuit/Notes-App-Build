import XCTest
@testable import InscribeCore
@testable import InscribeStorage

final class StrokeFileManagerTests: XCTestCase {

    /// Test that saving and loading strokes preserves data
    func testSaveAndLoadRoundTrip() async throws {
        let manager = StrokeFileManager.shared
        let pageID = UUID()

        let points = [
            InkPoint(location: CGPoint(x: 10, y: 20), pressure: 0.5, azimuth: 0.5, altitude: .pi / 3),
            InkPoint(location: CGPoint(x: 30, y: 40), pressure: 0.8, azimuth: 0.7, altitude: .pi / 4, roll: 1.0),
            InkPoint(location: CGPoint(x: 50, y: 60), pressure: 0.3, azimuth: 0.2, altitude: .pi / 2)
        ]

        let originalStroke = Stroke(
            id: UUID(),
            points: points,
            toolType: .fountainPen,
            color: PlatformColor(red: 1.0, green: 0.5, blue: 0.25),
            width: 3.5
        )

        try await manager.saveStrokes([originalStroke], pageID: pageID)

        // Verify file exists
        XCTAssertTrue(manager.hasStrokeData(pageID: pageID))

        // Load and verify
        let loaded = try manager.loadStrokes(pageID: pageID)
        XCTAssertEqual(loaded.count, 1)

        let loadedStroke = loaded[0]
        XCTAssertEqual(loadedStroke.id, originalStroke.id)
        XCTAssertEqual(loadedStroke.toolType, originalStroke.toolType)
        XCTAssertEqual(loadedStroke.width, originalStroke.width, accuracy: 0.1)
        XCTAssertEqual(loadedStroke.color.red, originalStroke.color.red, accuracy: 0.01)
        XCTAssertEqual(loadedStroke.color.green, originalStroke.color.green, accuracy: 0.01)
        XCTAssertEqual(loadedStroke.color.blue, originalStroke.color.blue, accuracy: 0.01)

        // Verify points
        XCTAssertEqual(loadedStroke.pointCount, 3)
        XCTAssertEqual(loadedStroke.points[0].location.x, 10, accuracy: 0.1)
        XCTAssertEqual(loadedStroke.points[1].location.y, 40, accuracy: 0.1)
        XCTAssertEqual(loadedStroke.points[2].pressure, 0.3, accuracy: 0.01)

        // Cleanup
        try manager.deleteStrokes(pageID: pageID)
        XCTAssertFalse(manager.hasStrokeData(pageID: pageID))
    }

    func testAppendStrokes() async throws {
        let manager = StrokeFileManager.shared
        let pageID = UUID()

        let stroke1 = Stroke(
            points: [InkPoint(location: .zero, pressure: 0.5)],
            toolType: .fountainPen
        )
        let stroke2 = Stroke(
            points: [InkPoint(location: CGPoint(x: 50, y: 50), pressure: 0.8)],
            toolType: .pencil
        )

        try await manager.saveStrokes([stroke1], pageID: pageID)
        try await manager.appendStrokes([stroke2], pageID: pageID)

        let loaded = try manager.loadStrokes(pageID: pageID)
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, stroke1.id)
        XCTAssertEqual(loaded[1].id, stroke2.id)

        try manager.deleteStrokes(pageID: pageID)
    }

    func testDeleteStroke() async throws {
        let manager = StrokeFileManager.shared
        let pageID = UUID()

        let stroke1 = Stroke(
            id: UUID(),
            points: [InkPoint(location: .zero, pressure: 0.5)],
            toolType: .fountainPen
        )
        let stroke2 = Stroke(
            id: UUID(),
            points: [InkPoint(location: CGPoint(x: 50, y: 50), pressure: 0.8)],
            toolType: .pencil
        )

        try await manager.saveStrokes([stroke1, stroke2], pageID: pageID)
        try await manager.deleteStroke(strokeID: stroke1.id, pageID: pageID)

        let loaded = try manager.loadStrokes(pageID: pageID)
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, stroke2.id)

        try manager.deleteStrokes(pageID: pageID)
    }

    func testLoadStrokeMetadata() async throws {
        let manager = StrokeFileManager.shared
        let pageID = UUID()

        let stroke = Stroke(
            id: UUID(),
            points: [
                InkPoint(location: .zero, pressure: 0.3),
                InkPoint(location: CGPoint(x: 10, y: 10), pressure: 0.5),
                InkPoint(location: CGPoint(x: 20, y: 0), pressure: 0.7)
            ],
            toolType: .marker,
            color: PlatformColor(red: 0, green: 0, blue: 1),
            width: 8.0
        )

        try await manager.saveStrokes([stroke], pageID: pageID)

        let metadata = try manager.loadStrokeMetadata(pageID: pageID)
        XCTAssertEqual(metadata.count, 1)
        XCTAssertEqual(metadata[0].width, 8.0, accuracy: 0.1)

        // Verify color
        let color = metadata[0].color
        XCTAssertEqual(color.blue, 1.0, accuracy: 0.01)

        try manager.deleteStrokes(pageID: pageID)
    }

    func testNoFileReturnsEmpty() throws {
        let manager = StrokeFileManager.shared
        let strokes = try manager.loadStrokes(pageID: UUID())
        XCTAssertTrue(strokes.isEmpty)
    }

    func testFileSizeReporting() async throws {
        let manager = StrokeFileManager.shared
        let pageID = UUID()

        let stroke = Stroke(points: [InkPoint(location: .zero, pressure: 0.5)])
        try await manager.saveStrokes([stroke], pageID: pageID)

        let size = manager.strokeDataSize(pageID: pageID)
        XCTAssertGreaterThan(size, 0)

        try manager.deleteStrokes(pageID: pageID)

        let sizeAfterDelete = manager.strokeDataSize(pageID: pageID)
        XCTAssertEqual(sizeAfterDelete, 0)
    }

    func testMultipleStrokesFileSize() async throws {
        let manager = StrokeFileManager.shared
        let pageID = UUID()

        var strokes: [Stroke] = []
        for i in 0..<10 {
            strokes.append(Stroke(
                points: [
                    InkPoint(location: CGPoint(x: 0, y: CGFloat(i * 10)), pressure: 0.5),
                    InkPoint(location: CGPoint(x: 100, y: CGFloat(i * 10)), pressure: 0.8)
                ],
                toolType: .fountainPen
            ))
        }

        try await manager.saveStrokes(strokes, pageID: pageID)
        let loaded = try manager.loadStrokes(pageID: pageID)
        XCTAssertEqual(loaded.count, 10)

        try manager.deleteStrokes(pageID: pageID)
    }
}
