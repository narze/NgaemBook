import AppKit
import SwiftUI

/// NgaemBook (แง้มบุ๊ค): a menu bar app that sleeps the display and turns off
/// the keyboard backlight when the lid folds below an angle.
@main
struct NgaemBookApp: App {
    @State private var controller = FoldController()

    init() {
        // No Dock icon and no window, also when run with `swift run`.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(controller: controller)
        } label: {
            Image(systemName: iconName)
                .accessibilityLabel("NgaemBook")
        }
    }

    private var iconName: String {
        if controller.sensorError != nil { return "laptopcomputer.trianglebadge.exclamationmark" }
        if !controller.isEnabled { return "pause.circle" }
        return controller.isFolded ? "laptopcomputer.slash" : "laptopcomputer"
    }
}

struct MenuContent: View {
    @Bindable var controller: FoldController

    var body: some View {
        Text(status)

        Divider()

        Toggle("Enabled", isOn: $controller.isEnabled)
        Picker("Fold Below", selection: $controller.threshold) {
            ForEach(FoldController.thresholds, id: \.self) { degrees in
                Text("\(degrees)°").tag(Double(degrees))
            }
        }

        Divider()

        Toggle("Sleep Display", isOn: $controller.sleepsDisplay)
        Toggle("Keep Display On with External Display", isOn: $controller.keepsDisplayWithExternal)
            .disabled(!controller.sleepsDisplay)
        Toggle("Turn Off Keyboard Backlight", isOn: $controller.turnsOffKeyboard)
            .disabled(!controller.isKeyboardBacklightAvailable)

        Divider()

        Toggle("Launch at Login", isOn: Binding(
            get: { controller.launchesAtLogin },
            set: { controller.setLaunchesAtLogin($0) }
        ))
        Button("Quit NgaemBook") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private var status: String {
        if let error = controller.sensorError { return "Lid sensor not found (\(error))" }
        guard controller.isEnabled else { return "Paused" }
        let angle = controller.angle.map { "\(Int($0.rounded()))°" } ?? "--°"
        return controller.isFolded ? "Folded at \(angle): display and keyboard light off" : "Lid at \(angle)"
    }
}
