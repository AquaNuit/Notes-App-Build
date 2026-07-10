import XCTest
@testable import InscribeCore

final class InkPointTests: XCTestCase {

    func testInkPointCreation() {
        let point = InkPoint(
            location: CGPoint(x: 100, y: 200),
            pressure: 0.75,
            azimuth: 0.5,
            altitude: .pi / 3,
            roll: 1.0,
            velocity: 300,
            timestamp: 12345
        )

        XCTAssertEqual(point.location.x, 100)
        XCTAssertEqual(point.location.y, 200)
        XCTAssertEqual(point.pressure, 0.75)
        XCTAssertEqual(point.azimuth, 0.5)
        XCTAssertEqual(point.altitude, .pi / 3, accuracy: 0.001)
        XCTAssertEqual(point.roll, 1.0)
        XCTAssertEqual(point.velocity, 300)
        XCTAssertEqual(point.timestamp, 12345)
        XCTAssertFalse(point.isPredicted)
        XCTAssertFalse(point.isCoalesced)
    }

    func testPressureClamping() {
        let over = InkPoint(location: .zero, pressure: 1.5)
        XCTAssertEqual(over.pressure, 1.0)

        let under = InkPoint(location: .zero, pressure: -0.5)
        XCTAssertEqual(under.pressure, 0.0)
    }

    func testInkPointEquality() {
        let a = InkPoint(location: CGPoint(x: 10, y: 20), pressure: 0.5, azimuth: 0, altitude: .pi / 2)
        let b = InkPoint(location: CGPoint(x: 10, y: 20), pressure: 0.5, azimuth: 0, altitude: .pi / 2)
        let c = InkPoint(location: CGPoint(x: 10, y: 21), pressure: 0.5, azimuth: 0, altitude: .pi / 2)

        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testDistanceCalculation() {
        let a = InkPoint(location: .zero, pressure: 0)
        let b = InkPoint(location: CGPoint(x: 3, y: 4), pressure: 0)

        XCTAssertEqual(a.distance(to: b), 5.0, accuracy: 0.001)
    }

    func testLinearInterpolation() {
        let a = InkPoint(location: .zero, pressure: 0.0, azimuth: 0, altitude: .pi / 2)
        let b = InkPoint(location: CGPoint(x: 10, y: 10), pressure: 1.0, azimuth: 0, altitude: .pi / 2)

        let mid = a.lerp(to: b, t: 0.5)
        XCTAssertEqual(mid.location.x, 5, accuracy: 0.001)
        XCTAssertEqual(mid.location.y, 5, accuracy: 0.001)
        XCTAssertEqual(mid.pressure, 0.5, accuracy: 0.001)
    }

    func testRollOptionality() {
        let withRoll = InkPoint(location: .zero, pressure: 0, roll: 1.5)
        let withoutRoll = InkPoint(location: .zero, pressure: 0, roll: nil)

        XCTAssertNotNil(withRoll.roll)
        XCTAssertNil(withoutRoll.roll)
    }

    func testIsUpright() {
        let upright = InkPoint(location: .zero, pressure: 0, altitude: .pi / 2)
        XCTAssertTrue(upright.isUpright)
        XCTAssertFalse(upright.isFlat)
    }

    func testCodableRoundTrip() throws {
        let original = InkPoint(
            location: CGPoint(x: 50, y: 150),
            pressure: 0.8,
            azimuth: 1.2,
            altitude: .pi / 4,
            roll: 2.5,
            velocity: 500,
            timestamp: 67890,
            isPredicted: true,
            isCoalesced: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(InkPoint.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    func testVelocityNonNegative() {
        let negative = InkPoint(location: .zero, pressure: 0, velocity: -100)
        XCTAssertGreaterThanOrEqual(negative.velocity, 0)
    }
}
