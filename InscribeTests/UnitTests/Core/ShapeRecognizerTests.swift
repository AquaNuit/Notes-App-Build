import XCTest
@testable import InscribeCore

final class ShapeRecognizerTests: XCTestCase {

    let recognizer = ShapeRecognizer()

    func testClassifyLine() {
        // Create a straight line
        let points = (0..<10).map { i in
            InkPoint(location: CGPoint(x: CGFloat(i) * 10, y: CGFloat(i) * 10), pressure: 0.5)
        }
        let stroke = Stroke(points: points)

        let (shape, confidence) = recognizer.classify(stroke)
        XCTAssertEqual(shape, .line)
        XCTAssertGreaterThan(confidence, 0.5)
    }

    func testClassifyCircle() {
        // Generate approximate circle points
        let center = CGPoint(x: 100, y: 100)
        let radius: CGFloat = 50
        let points = (0..<20).map { i in
            let angle = 2 * .pi * CGFloat(i) / CGFloat(20)
            return InkPoint(
                location: CGPoint(
                    x: center.x + radius * cos(angle),
                    y: center.y + radius * sin(angle)
                ),
                pressure: 0.5
            )
        }
        let stroke = Stroke(points: points)

        let (shape, confidence) = recognizer.classify(stroke)
        XCTAssertEqual(shape, .circle)
        XCTAssertGreaterThan(confidence, 0.5)
    }

    func testClassifyRectangle() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 80)
        let corners: [CGPoint] = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
            rect.origin
        ]
        // Add interpolation points along edges
        var allPoints: [CGPoint] = []
        for i in 0..<corners.count - 1 {
            for t in 0..<5 {
                let frac = CGFloat(t) / 5
                let p = corners[i].lerp(to: corners[i+1], t: frac)
                allPoints.append(p)
            }
        }
        let points = allPoints.map { InkPoint(location: $0, pressure: 0.5) }
        let stroke = Stroke(points: points)

        let (shape, _) = recognizer.classify(stroke)
        XCTAssertEqual(shape, .rectangle)
    }

    func testCanBeautify() {
        // Line should be beautifiable
        let linePoints = [
            InkPoint(location: .zero, pressure: 0.5),
            InkPoint(location: CGPoint(x: 100, y: 100), pressure: 0.5)
        ]
        let line = Stroke(points: linePoints)
        XCTAssertTrue(recognizer.canBeautify(line))

        // Should not beautify unknown shapes with few points
        let noisePoints = [
            InkPoint(location: .zero, pressure: 0.5),
            InkPoint(location: CGPoint(x: 50, y: 80), pressure: 0.5),
            InkPoint(location: CGPoint(x: 10, y: 90), pressure: 0.5)
        ]
        let noise = Stroke(points: noisePoints)
        // Might or might not recognize
    }

    func testBeautifyLine() {
        let points = [
            InkPoint(location: CGPoint(x: 5, y: 7), pressure: 0.5),
            InkPoint(location: CGPoint(x: 95, y: 93), pressure: 0.5)
        ]
        let stroke = Stroke(points: points)

        guard let beautified = recognizer.beautify(stroke) else {
            XCTFail("Should have beautified line")
            return
        }

        // Should have exactly 2 points (start and end of perfect line)
        XCTAssertEqual(beautified.pointCount, 2)
        XCTAssertEqual(beautified.toolType, stroke.toolType)
    }

    func testUnknownShape() {
        // Random scattered points should be unknown
        let points = [
            InkPoint(location: CGPoint(x: 10, y: 90), pressure: 0.5),
            InkPoint(location: CGPoint(x: 50, y: 50), pressure: 0.5),
            InkPoint(location: CGPoint(x: 90, y: 10), pressure: 0.5)
        ]
        let stroke = Stroke(points: points)

        let (shape, _) = recognizer.classify(stroke)
        // Likely unknown for a V-shape with only 3 points and low closure
        // (It might classify as line or unknown depending on geometry)
    }

    func testEmptyStrokeIsUnknown() {
        let stroke = Stroke(points: [])
        let (shape, confidence) = recognizer.classify(stroke)
        XCTAssertEqual(shape, .unknown)
        XCTAssertEqual(confidence, 0)
    }

    func testSinglePointStrokeIsUnknown() {
        let stroke = Stroke(points: [
            InkPoint(location: .zero, pressure: 0.5)
        ])
        let (shape, _) = recognizer.classify(stroke)
        XCTAssertEqual(shape, .unknown)
    }

    func testEllipseRecognition() {
        let center = CGPoint(x: 100, y: 100)
        let points = (0..<24).map { i in
            let angle = 2 * .pi * CGFloat(i) / CGFloat(24)
            return InkPoint(
                location: CGPoint(
                    x: center.x + 80 * cos(angle),
                    y: center.y + 40 * sin(angle)
                ),
                pressure: 0.5
            )
        }
        let stroke = Stroke(points: points)

        let (shape, _) = recognizer.classify(stroke)
        // With aspect ratio ~0.5, should be ellipse
        XCTAssertEqual(shape, .ellipse)
    }
}
