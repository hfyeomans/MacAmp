import AppKit

enum WinampAlertHelper {
    /// Show a simple informational alert with OK button.
    @MainActor
    static func showInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Show an error/warning alert with OK button.
    @MainActor
    static func showError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Prompt for text input. Returns the entered string, or nil if cancelled.
    @MainActor
    static func promptText(title: String, message: String, placeholder: String = "", defaultValue: String = "") -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = placeholder
        textField.stringValue = defaultValue
        alert.accessoryView = textField
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        return textField.stringValue
    }
}
