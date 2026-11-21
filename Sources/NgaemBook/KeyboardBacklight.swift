import Foundation
import ObjectiveC

/// Turns the built-in keyboard backlight off and back on.
///
/// macOS has no public API for this, so it uses `KeyboardBrightnessClient`
/// from the private CoreBrightness framework (as Control Center does).
/// If the class is missing, `isAvailable` is false and the calls do nothing.
@MainActor
final class KeyboardBacklight {
    private typealias GetFloat = @convention(c) (AnyObject, Selector, UInt64) -> Float
    private typealias GetBool = @convention(c) (AnyObject, Selector, UInt64) -> Bool
    private typealias SetFloat = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
    private typealias SetBool = @convention(c) (AnyObject, Selector, Bool, UInt64) -> Bool

    private let client: NSObject?
    private let keyboardID: UInt64?
    /// The state before `turnOff`, restored by `restore`.
    private var saved: (level: Float, auto: Bool)?

    var isAvailable: Bool { client != nil && keyboardID != nil }

    init() {
        dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
        guard let type = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type,
              type.instancesRespond(to: NSSelectorFromString("setBrightness:forKeyboard:")) else {
            client = nil
            keyboardID = nil
            return
        }
        let client = type.init()
        self.client = client
        let ids = client.perform(NSSelectorFromString("copyKeyboardBacklightIDs"))?
            .takeRetainedValue() as? [NSNumber] ?? []
        keyboardID = ids.map(\.uint64Value).first { id in
            Self.call(client, "isKeyboardBuiltIn:", GetBool.self) { $0(client, $1, id) } ?? false
        }
    }

    /// Saves the current level and auto-brightness, then turns the light off.
    func turnOff() {
        guard saved == nil, let client, let id = keyboardID else { return }
        let level = Self.call(client, "brightnessForKeyboard:", GetFloat.self) { $0(client, $1, id) } ?? 0
        let auto = Self.call(client, "isAutoBrightnessEnabledForKeyboard:", GetBool.self) { $0(client, $1, id) } ?? false
        saved = (level, auto)
        // Auto-brightness would turn the light on again.
        if auto { setAuto(false) }
        setLevel(0)
    }

    /// Puts back the state from before `turnOff`.
    func restore() {
        guard let saved else { return }
        self.saved = nil
        setLevel(saved.level)
        if saved.auto { setAuto(true) }
    }

    private func setLevel(_ level: Float) {
        guard let client, let id = keyboardID else { return }
        _ = Self.call(client, "setBrightness:forKeyboard:", SetFloat.self) { $0(client, $1, level, id) }
    }

    private func setAuto(_ enabled: Bool) {
        guard let client, let id = keyboardID else { return }
        _ = Self.call(client, "enableAutoBrightness:forKeyboard:", SetBool.self) { $0(client, $1, enabled, id) }
    }

    /// Calls an Objective-C method through its C function pointer, if the object responds to it.
    private static func call<F, R>(_ object: NSObject, _ name: String, _: F.Type, _ body: (F, Selector) -> R) -> R? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector), let method = class_getInstanceMethod(type(of: object), selector) else {
            return nil
        }
        return body(unsafeBitCast(method_getImplementation(method), to: F.self), selector)
    }
}
