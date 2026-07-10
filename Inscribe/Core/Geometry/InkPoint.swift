import CoreGraphics
import Foundation

// MARK: - InkPoint

/// A single point in a stroke, containing all Apple Pencil input data.
///
/// InkPoint captures the full state of the Pencil at a moment in time,
/// including pressure, tilt (azimuth/altitude), roll (Pencil Pro),
/// velocity, and timing information.
public struct InkPoint: Codable, Equatable, Sendable {
    /// Position in canvas coordinate space
    public var location: CGPoint

    /// Normalized pressure 0.0 (no contact) to 1.0 (maximum force)
    /// Maps from `touch.force / touch.maximumPossibleForce`
    public var pressure: CGFloat

    /// Azimuth angle of the Pencil in radians.
    /// 0 = pointing to the right on the screen, increasing counter-clockwise.
    public var azimuth: CGFloat

    /// Altitude angle of the Pencil in radians.
    /// 0 = parallel to screen, π/2 = perpendicular to screen.
    public var altitude: CGFloat

    /// Roll angle of the Pencil in radians (Apple Pencil Pro only).
    /// nil on devices that don't support roll.
    public var roll: CGFloat?

    /// Instantaneous velocity in points per second.
    /// Calculated from the distance between this point and the previous point.
    public var velocity: CGFloat

    /// Timestamp from the UITouch event (seconds since device boot).
    public var timestamp: TimeInterval

    /// Whether this point was predicted by the system
    public var isPredicted: Bool

    /// Whether this point was coalesced (interpolated by the system between real touches)
    public var isCoalesced: Bool

    // MARK: - Initialization

    public init(
        location: CGPoint,
        pressure: CGFloat,
        azimuth: CGFloat = 0,
        altitude: CGFloat = .pi / 2,
        roll: CGFloat? = nil,
        velocity: CGFloat = 0,
        timestamp: TimeInterval = 0,
        isPredicted: Bool = false,
        isCoalesced: Bool = false
    ) {
        self.location = location
        self.pressure = pressure.clamped(to: 0...1)
        self.azimuth = azimuth
        self.altitude = altitude.clamped(to: 0...(.pi / 2))
        self.roll = roll
        self.velocity = max(0, velocity)
        self.timestamp = timestamp
        self.isPredicted = isPredicted
        self.isCoalesced = isCoalesced
    }

    // MARK: - Helpers

    /// The force of the touch as a CGFloat in the range 0-1
    public var normalizedPressure: CGFloat {
        pressure
    }

    /// Whether the Pencil is nearly perpendicular to the screen
    public var isUpright: Bool {
        altitude > (.pi / 4)
    }

    /// Whether the Pencil is nearly flat against the screen
    public var isFlat: Bool {
        altitude < (.pi / 6)
    }
}

// MARK: - InkPoint Codable

extension InkPoint {
    private enum CodingKeys: String, CodingKey {
        case locationX, locationY, pressure, azimuth, altitude
        case roll, velocity, timestamp, isPredicted, isCoalesced
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(location.x, forKey: .locationX)
        try container.encode(location.y, forKey: .locationY)
        try container.encode(pressure, forKey: .pressure)
        try container.encode(azimuth, forKey: .azimuth)
        try container.encode(altitude, forKey: .altitude)
        try container.encodeIfPresent(roll, forKey: .roll)
        try container.encode(velocity, forKey: .velocity)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isPredicted, forKey: .isPredicted)
        try container.encode(isCoalesced, forKey: .isCoalesced)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x: CGFloat = try container.decode(CGFloat.self, forKey: .locationX)
        let y: CGFloat = try container.decode(CGFloat.self, forKey: .locationY)
        self.location = CGPoint(x: x, y: y)
        self.pressure = try container.decode(CGFloat.self, forKey: .pressure)
        self.azimuth = try container.decode(CGFloat.self, forKey: .azimuth)
        self.altitude = try container.decode(CGFloat.self, forKey: .altitude)
        self.roll = try container.decodeIfPresent(CGFloat.self, forKey: .roll)
        self.velocity = try container.decode(CGFloat.self, forKey: .velocity)
        self.timestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        self.isPredicted = try container.decode(Bool.self, forKey: .isPredicted)
        self.isCoalesced = try container.decode(Bool.self, forKey: .isCoalesced)
    }
}

// MARK: - InkPoint Utilities

public extension InkPoint {
    /// Distance from this point to another in canvas coordinates
    func distance(to other: InkPoint) -> CGFloat {
        location.distance(to: other.location)
    }

    /// Linear interpolation between two points
    func lerp(to other: InkPoint, t: CGFloat) -> InkPoint {
        InkPoint(
            location: location.lerp(to: other.location, t: t),
            pressure: pressure + (other.pressure - pressure) * t,
            azimuth: azimuth + (other.azimuth - azimuth) * t,
            altitude: altitude + (other.altitude - altitude) * t,
            roll: roll.map { r in r + ((other.roll ?? r) - r) * t } ?? other.roll,
            velocity: velocity + (other.velocity - velocity) * t,
            timestamp: timestamp + (other.timestamp - timestamp) * TimeInterval(t),
            isPredicted: other.isPredicted,
            isCoalesced: other.isCoalesced
        )
    }

    /// Midpoint between two points
    static func midpoint(_ a: InkPoint, _ b: InkPoint) -> InkPoint {
        a.lerp(to: b, t: 0.5)
    }
}
