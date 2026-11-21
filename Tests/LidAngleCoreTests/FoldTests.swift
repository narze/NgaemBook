import Testing
@testable import LidAngleCore

@Suite("FoldDetector")
struct FoldDetectorTests {
    @Test("Starts open")
    func startsOpen() {
        #expect(!FoldDetector(threshold: 25).isFolded)
    }

    @Test("Folds when the angle goes below the threshold")
    func folds() {
        var detector = FoldDetector(threshold: 25)
        #expect(detector.update(angle: 90) == nil)
        #expect(detector.update(angle: 25) == nil)   // not below
        #expect(detector.update(angle: 24) == .folded)
        #expect(detector.isFolded)
    }

    @Test("Reports a fold only once")
    func foldsOnce() {
        var detector = FoldDetector(threshold: 25)
        detector.update(angle: 20)
        #expect(detector.update(angle: 10) == nil)
        #expect(detector.update(angle: 0) == nil)
    }

    @Test("Opens only at the threshold plus hysteresis")
    func hysteresis() {
        var detector = FoldDetector(threshold: 25)
        detector.update(angle: 20)
        #expect(detector.update(angle: 25) == nil)
        #expect(detector.update(angle: 25 + FoldDetector.hysteresis - 1) == nil)
        #expect(detector.update(angle: 25 + FoldDetector.hysteresis) == .unfolded)
        #expect(!detector.isFolded)
    }

    @Test("A new threshold applies on the next reading")
    func changeThreshold() {
        var detector = FoldDetector(threshold: 25)
        detector.update(angle: 30)
        detector.threshold = 35
        #expect(detector.update(angle: 30) == .folded)
    }

    @Test("Reset opens without an event")
    func reset() {
        var detector = FoldDetector(threshold: 25)
        detector.update(angle: 10)
        detector.reset()
        #expect(!detector.isFolded)
        #expect(detector.update(angle: 10) == .folded)
    }
}

@Suite("PollSchedule")
struct PollScheduleTests {
    @Test("Slow when the lid is far above the threshold")
    func far() {
        #expect(PollSchedule.interval(angle: 110, threshold: 25, isFolded: false) == PollSchedule.idle)
        #expect(PollSchedule.interval(angle: 25 + PollSchedule.nearRange, threshold: 25, isFolded: false) == PollSchedule.idle)
    }

    @Test("Fast when the lid is near the threshold")
    func near() {
        #expect(PollSchedule.interval(angle: 40, threshold: 25, isFolded: false) == PollSchedule.near)
        #expect(PollSchedule.interval(angle: 26, threshold: 25, isFolded: false) == PollSchedule.near)
    }

    @Test("Medium while folded, to see the lid open")
    func folded() {
        #expect(PollSchedule.interval(angle: 10, threshold: 25, isFolded: true) == PollSchedule.folded)
    }

    @Test("Very slow when the sensor cannot be read")
    func noReading() {
        #expect(PollSchedule.interval(angle: nil, threshold: 25, isFolded: false) == PollSchedule.unavailable)
    }

    @Test("Intervals go from fast to slow")
    func order() {
        #expect(PollSchedule.near < PollSchedule.folded)
        #expect(PollSchedule.folded < PollSchedule.idle)
        #expect(PollSchedule.idle < PollSchedule.unavailable)
    }
}
