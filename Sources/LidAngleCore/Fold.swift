public enum FoldEvent: Equatable, Sendable {
    case folded
    case unfolded
}

/// Finds when the lid folds below a threshold angle and when it opens again.
///
/// Folded: the angle is below `threshold`. Open again: the angle is at
/// `threshold + hysteresis` or more, so the state does not flip at the limit.
public struct FoldDetector: Sendable {
    public static let hysteresis = 3.0

    public var threshold: Double
    public private(set) var isFolded = false

    public init(threshold: Double) {
        self.threshold = threshold
    }

    /// Adds a reading. Returns an event when the state changes.
    @discardableResult
    public mutating func update(angle: Double) -> FoldEvent? {
        if !isFolded, angle < threshold {
            isFolded = true
            return .folded
        }
        if isFolded, angle >= threshold + Self.hysteresis {
            isFolded = false
            return .unfolded
        }
        return nil
    }

    /// Goes back to open without an event (for example when the feature is turned off).
    public mutating func reset() {
        isFolded = false
    }
}

/// How long to wait before the next sensor read. Each read wakes the CPU,
/// so read slowly when a fold cannot happen soon.
public enum PollSchedule {
    /// The lid is near the threshold: a fold can happen at any moment.
    public static let near = 0.25
    /// Folded: watch for the lid to open.
    public static let folded = 0.5
    /// The lid is far above the threshold.
    public static let idle = 1.0
    /// The sensor cannot be read.
    public static let unavailable = 5.0
    /// Degrees above the threshold that count as near.
    public static let nearRange = 20.0

    public static func interval(angle: Double?, threshold: Double, isFolded: Bool) -> Double {
        guard let angle else { return unavailable }
        if isFolded { return folded }
        return angle < threshold + nearRange ? near : idle
    }
}
