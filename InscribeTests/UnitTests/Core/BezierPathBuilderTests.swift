import XCTest
@testable import InscribeCore

final class BezierPathBuilderTests: XCTestCase {

    func testTwoPointsGeneratesLineSegment() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100)
        ]

        let segments = BezierPathBuilder.buildCubicBezierSegments(from: points)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].start, points[0])
        XCTAssertEqual(segments[0].end, points[1])
    }

    func testThreePointsGeneratesTwoSegments() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 100),
            CGPoint(x: 100, y: 0)
        ]

        let segments = BezierPathBuilder.buildCubicBezierSegments(from: points)
        XCTAssertEqual(segments.count, 2)
    }

    func testEmptyPointsReturnsEmpty() {
        let segments = BezierPathBuilder.buildCubicBezierSegments(from: [])
        XCTAssertTrue(segments.isEmpty)
    }

    func testSinglePointReturnsEmpty() {
        let segments = BezierPathBuilder.buildCubicBezierSegments(from: [CGPoint(x: 0, y: 0)])
        XCTAssertTrue(segments.isEmpty)
    }

    func testCubicBezierEvaluation() {
        let segment = CubicBezierSegment(
            start: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: 0, y: 100),
            control2: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 100, y: 0)
        )

        // t=0: start point
        let start = BezierPathBuilder.evaluateCubicBezier(segment: segment, t: 0)
        XCTAssertEqual(start.x, 0, accuracy: 0.001)
        XCTAssertEqual(start.y, 0, accuracy: 0.001)

        // t=1: end point
        let end = BezierPathBuilder.evaluateCubicBezier(segment: segment, t: 1)
        XCTAssertEqual(end.x, 100, accuracy: 0.001)
        XCTAssertEqual(end.y, 0, accuracy: 0.001)
    }

    func testGenerateWidthPath() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 50, y: 50),
            CGPoint(x: 100, y: 0)
        ]
        let widths: [CGFloat] = [1.0, 2.0, 3.0]

        let path = BezierPathBuilder.generateWidthPath(
            from: points,
            widths: widths,
            segmentsPerPoint: 4
        )

        XCTAssertFalse(path.isEmpty)
        XCTAssertEqual(path.first?.position, points[0])
        XCTAssertEqual(path.last?.position, points[2])

        // Width should be interpolated
        XCTAssertEqual(path.first?.width, 1.0, accuracy: 0.1)
        XCTAssertEqual(path.last?.width, 3.0, accuracy: 0.1)
    }

    func testCubicBezierBounds() {
        let segment = CubicBezierSegment(
            start: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: -50, y: 100),
            control2: CGPoint(x: 150, y: 100),
            end: CGPoint(x: 100, y: 0)
        )

        let bounds = segment.bounds
        XCTAssertLessThanOrEqual(bounds.minX, 0)
        XCTAssertGreaterThanOrEqual(bounds.maxX, 100)
    }

    func testApproximateLength() {
        let segment = CubicBezierSegment(
            start: CGPoint(x: 0, y: 0),
            control1: CGPoint(x: 0, y: 100),
            control2: CGPoint(x: 100, y: 100),
            end: CGPoint(x: 100, y: 0)
        )

        let length = segment.approximateLength(subdivisions: 20)
        // Should be longer than the straight-line distance (100) because of the curve
        XCTAssertGreaterThan(length, 100)
    }

    func testWidthPathWithMismatchedCounts() {
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 10)]
        let widths: [CGFloat] = [1.0] // Mismatched

        // Should still work, falling back to first width
        let path = BezierPathBuilder.generateWidthPath(from: points, widths: widths)
        XCTAssertFalse(path.isEmpty)
    }

    func testPerformanceOfBezierBuild() {
        let points = (0..<100).map { i in
            CGPoint(x: CGFloat(i) * 10, y: sin(CGFloat(i) * 0.1) * 50)
        }

        measure {
            let _ = BezierPathBuilder.buildCubicBezierSegments(from: points)
        }
    }
}
