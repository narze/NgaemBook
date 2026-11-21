import AppKit
import LidAngleCore
import Observation
import ServiceManagement
import os

private let log = Logger(subsystem: "com.narze.NgaemBook", category: "fold")

/// Reads the lid angle at an adaptive rate and, when the lid folds below the
/// threshold, sleeps the display and turns off the keyboard backlight.
/// Opening the lid again puts both back.
@MainActor
@Observable
final class FoldController {
    static let thresholds = [10, 15, 20, 25, 30, 35, 40, 45, 60]
    static let sleepAgainDelay = 3.0

    private enum Key {
        static let enabled = "enabled"
        static let threshold = "threshold"
        static let sleepsDisplay = "sleepsDisplay"
        static let keepsDisplayWithExternal = "keepsDisplayWithExternal"
        static let turnsOffKeyboard = "turnsOffKeyboard"
    }

    private(set) var angle: Double?
    private(set) var isFolded = false
    private(set) var sensorError: String?
    private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Key.enabled)
            if !isEnabled { open() }
            pollNow()
        }
    }

    var threshold: Double {
        didSet {
            defaults.set(threshold, forKey: Key.threshold)
            detector.threshold = threshold
            pollNow()
        }
    }

    var sleepsDisplay: Bool {
        didSet { defaults.set(sleepsDisplay, forKey: Key.sleepsDisplay) }
    }

    /// Display sleep turns off all displays, so skip it when an external display is on.
    var keepsDisplayWithExternal: Bool {
        didSet { defaults.set(keepsDisplayWithExternal, forKey: Key.keepsDisplayWithExternal) }
    }

    var turnsOffKeyboard: Bool {
        didSet { defaults.set(turnsOffKeyboard, forKey: Key.turnsOffKeyboard) }
    }

    var isKeyboardBacklightAvailable: Bool { backlight.isAvailable }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let sensor: LidAngleSensor?
    @ObservationIgnored private let backlight = KeyboardBacklight()
    @ObservationIgnored private var detector: FoldDetector
    @ObservationIgnored private var didSleepDisplay = false
    @ObservationIgnored private let timer = DispatchSource.makeTimerSource(queue: .main)

    init(defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.threshold: 25.0,
            Key.sleepsDisplay: true,
            Key.keepsDisplayWithExternal: true,
            Key.turnsOffKeyboard: true,
        ])
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Key.enabled)
        threshold = defaults.double(forKey: Key.threshold)
        sleepsDisplay = defaults.bool(forKey: Key.sleepsDisplay)
        keepsDisplayWithExternal = defaults.bool(forKey: Key.keepsDisplayWithExternal)
        turnsOffKeyboard = defaults.bool(forKey: Key.turnsOffKeyboard)
        detector = FoldDetector(threshold: defaults.double(forKey: Key.threshold))
        do {
            sensor = try LidAngleSensor()
        } catch {
            sensor = nil
            sensorError = String(describing: error)
        }

        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.activate()
        pollNow()

        let workspace = NSWorkspace.shared.notificationCenter
        // The timer does not run while the Mac sleeps: read again at once on wake.
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.pollNow() }
        }
        // A touch on the trackpad or keyboard wakes the screen: sleep it again while folded.
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensDidWake() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.open() }
        }
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("NgaemBook: launch at login failed: \(error)")
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func screensDidWake() {
        guard isFolded, didSleepDisplay else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.sleepAgainDelay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.isFolded, self.didSleepDisplay else { return }
                log.notice("Screen woke while folded: sleeping it again")
                DisplayPower.sleep()
            }
        }
    }

    private func pollNow() {
        schedule(after: 0)
    }

    private func poll() {
        guard isEnabled else {
            // Paused: no reads at all.
            if angle != nil { angle = nil }
            return
        }
        let reading = sensor?.readAngle()
        if reading != angle { angle = reading }
        if let reading, let event = detector.update(angle: reading) {
            switch event {
            case .folded: fold()
            case .unfolded: open()
            }
        }
        schedule(after: PollSchedule.interval(angle: reading, threshold: threshold, isFolded: detector.isFolded))
    }

    /// One-shot timer with 10% leeway, so macOS can group the wakeup with others.
    private func schedule(after seconds: Double) {
        let leeway = DispatchTimeInterval.milliseconds(Int(seconds * 100))
        timer.schedule(deadline: .now() + seconds, repeating: .never, leeway: leeway)
    }

    private func fold() {
        isFolded = true
        if turnsOffKeyboard {
            backlight.turnOff()
        }
        if sleepsDisplay, !(keepsDisplayWithExternal && DisplayPower.hasExternalDisplay) {
            didSleepDisplay = DisplayPower.sleep()
        }
        log.notice("Folded at \(self.angle ?? -1) deg: keyboard off \(self.turnsOffKeyboard), display slept \(self.didSleepDisplay)")
    }

    /// Puts the display and keyboard backlight back. Safe to call when not folded.
    private func open() {
        if isFolded { log.notice("Opened at \(self.angle ?? -1) deg: restoring display and keyboard") }
        isFolded = false
        detector.reset()
        backlight.restore()
        if didSleepDisplay {
            didSleepDisplay = false
            DisplayPower.wake()
        }
    }
}
