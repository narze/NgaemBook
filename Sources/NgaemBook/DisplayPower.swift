import CoreGraphics
import Foundation
import IOKit.pwr_mgt

/// Sleeps and wakes the displays.
enum DisplayPower {
    /// Puts all displays to sleep, as `pmset displaysleepnow` does. The Mac stays awake.
    @discardableResult
    static func sleep() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// Wakes the displays by declaring user activity (public IOKit API).
    static func wake() {
        var assertion: IOPMAssertionID = 0
        let result = IOPMAssertionDeclareUserActivity(
            "NgaemBook: lid opened" as CFString, kIOPMUserActiveLocal, &assertion
        )
        if result == kIOReturnSuccess {
            IOPMAssertionRelease(assertion)
        }
    }

    /// True when a display other than the built-in one is on.
    static var hasExternalDisplay: Bool {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &displays, &count) == .success else { return false }
        return displays.prefix(Int(count)).contains { CGDisplayIsBuiltin($0) == 0 }
    }
}
