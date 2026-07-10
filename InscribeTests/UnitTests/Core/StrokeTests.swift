import XCTest
@testable import InscribeCore

final class StrokeTests: XCTestCase {

    func testStrokeCreation() {
        let points = [
            InkPoint(location: .zero, pressure: 0.5),
            InkPoint(location: CGPoint(x: 10, y: 10), pressure: 0.8),
            InkPoint(location: CGPoint(x: 20, y: 5), pressure: 0.6)
        ]

        let stroke = Stroke(
            points: points,
            toolType: .fountainPen,
            color: .black,
            width: 2.0
        )

        XCTAssertEqual(stroke.pointCount, 3)
        XCTAssertEqual(stroke.toolType, .fountainPen)
        XCTAssertEqual(stroke.width, 2.0)
        XCTAssertTrue(stroke.isVisible)
        XCTAssertFalse(stroke.bounds.isEmpty)
    }

    func testStrokeBounds() {
        let points = [
            InkPoint(location: CGPoint(x: 0, y: 0), pressure: 0),
            InkPoint(location: CGPoint(x: 100, y: 50), pressure: 0),
            InkPoint(location: CGPoint(x: 50, y: 100), pressure: 0)
        ]

        let stroke = Stroke(points: points, width: 10)

        let bounds = stroke.bounds
        XCTAssertEqual(bounds.minX, -5, accuracy: 0.1)
        XCTAssertEqual(bounds.minY, -5, accuracy: 0.1)
        XCTAssertEqual(bounds.maxX, 105, accuracy: 0.1)
        XCTAssertEqual(bounds.maxY, 105, accuracy: 0.1)
    }

    func testStrokeLength() {
        let points = [
            InkPoint(location: CGPoint(x: 0, y: 0), pressure: 0),
            InkPoint(location: CGPoint(x: 3, y: 4), pressure: 0),
            InkPoint(location: CGPoint(x: 3, y: 14), pressure: 0) // 10 more pts
        ]

        let stroke = Stroke(points: points)
        // 5 + 10 = 15
        XCTAssertEqual(stroke.length, 15, accuracy: 0.1)
    }

    func testSimplifyWithRamerDouglasPeucker() {
        // Create a nearly straight line with some noise
        var points: [InkPoint] = []
        for i in 0..<100 {
            let noise = i % 10 == 5 ? CGFloat(5) : CGFloat(0) // One outlier
            points.append(InkPoint(
                location: CGPoint(x: CGFloat(i), y: CGFloat(i) + noise),
                pressure: 0.5
            ))
        }

        let stroke = Stroke(points: points)
        let simplified = stroke.simplified(epsilon: 2.0)

        // Should have removed the noise points
        XCTAssertLessThan(simplified.pointCount, stroke.pointCount)
        XCTAssertGreaterThanOrEqual(simplified.pointCount, 2)
    }

    func testAveragePressure() {
        let points = [
            InkPoint(location: .zero, pressure: 0.2),
            InkPoint(location: CGPoint(x: 10, y: 0), pressure: 0.6),
            InkPoint(location: CGPoint(x: 20, y: 0), pressure: 1.0)
        ]

        let stroke = Stroke(points: points)
        XCTAssertEqual(stroke.averagePressure, 0.6, accuracy: 0.001)
    }

    func testEmptyStrokeBounds() {
        let stroke = Stroke(points: [])
        XCTAssertTrue(stroke.bounds.isEmpty)
    }

    func testSinglePointStroke() {
        let stroke = Stroke(points: [InkPoint(location: .zero, pressure: 0.5)])
        XCTAssertEqual(stroke.pointCount, 1)
    }

    func testToolTypeProperties() {
        XCTAssertTrue(ToolType.fountainPen.isEraser == false)
        XCTAssertTrue(ToolType.eraserPixel.isEraser == true)
        XCTAssertTrue(ToolType.lasso.isSelectionTool == true)
        XCTAssertFalse(ToolType.pencil.isSelectionTool)
    }

    func testPlatformColorRGBA() {
        let color = PlatformColor(red: 1.0, green: 0.5, blue: 0.25)
        let rgba = color.rgbaUInt32

        let restored = PlatformColor.from(rgba: rgba)
        XCTAssertEqual(restored.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(restored.green, 0.5, accuracy: 0.01)
        XCTAssertEqual(restored.blue, 0.25, accuracy: 0.01)
        XCTAssertEqual(restored.alpha, 1.0, accuracy: 0.01)
    }

    func testStrokeCollectionIntersection() {
        let strokes = [
            Stroke(points: [InkPoint(location: CGPoint(x: 0, y: 0), pressure: 0)],
                   width: 2),
            Stroke(points: [InkPoint(location: CGPoint(x: 100, y: 100), pressure: 0)],
                   width: 2),
            Stroke(points: [InkPoint(location: CGPoint(x: 200, y: 200), pressure: 0)],
                   width: 2)
        ]

        let intersecting = strokes.strokesIntersecting(CGRect(x: 50, y: 50, width: 100, height: 100))
        XCTAssertEqual(intersecting.count, 1)
        XCTAssertEqual(intersecting.first?.id, strokes[1].id)
    }
}
