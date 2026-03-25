import AppKit
import UserNotifications

private enum SkinImportError: LocalizedError {
    case unsupportedExtension(String)
    case remoteURL
    case oversizedFile
    case directoryCreationFailed(String)
    case validationFailed(String)
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedExtension(let ext):
            return "Unsupported skin file type: .\(ext). Please import a .wsz or .zip file."
        case .remoteURL:
            return "Only local skin files can be imported."
        case .oversizedFile:
            return "Skin file is larger than the 50 MB limit."
        case .directoryCreationFailed(let message):
            return "Unable to access the skins directory: \(message)"
        case .validationFailed(let message):
            return "Unable to validate skin file: \(message)"
        case .copyFailed(let message):
            return "Failed to copy skin: \(message)"
        }
    }
}

extension SkinManager {
    private static var allowedSkinExtensions: Set<String> { ["wsz", "zip"] }
    private static var maxImportSizeBytes: Int { 50 * 1024 * 1024 }

    /// Import a skin from an external URL (copies to user skins directory)
    func importSkin(from sourceURL: URL) async {
        let fileManager = FileManager.default
        let fallbackName = sourceURL.deletingPathExtension().lastPathComponent

        do {
            let validatedSource = try validateImportURL(sourceURL)
            let skinName = validatedSource.deletingPathExtension().lastPathComponent
            let destinationDirectory: URL
            do {
                destinationDirectory = try AppSettings.userSkinsDirectory()
            } catch {
                throw SkinImportError.directoryCreationFailed(error.localizedDescription)
            }
            let destinationURL = destinationDirectory.appendingPathComponent(validatedSource.lastPathComponent)
            try ensureDestination(destinationURL, isWithin: destinationDirectory)

            if fileManager.fileExists(atPath: destinationURL.path) {
                let response = await presentReplacementPrompt(for: skinName)
                if response == .alertSecondButtonReturn {
                    return
                }
                try fileManager.removeItem(at: destinationURL)
            }

            do {
                try fileManager.copyItem(at: validatedSource, to: destinationURL)
            } catch {
                throw SkinImportError.copyFailed(error.localizedDescription)
            }

            AppLog.info(.skin, "Imported skin: \(skinName) to \(destinationURL.path)")
            loadingError = nil

            scanAvailableSkins()
            let newSkinID = "user:\(skinName)"
            switchToSkin(identifier: newSkinID)
            showNotification(title: "Skin Imported", message: "\(skinName) has been imported successfully.")
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            AppLog.error(.skin, "Failed to import skin: \(message)")
            loadingError = message
            await presentImportFailureAlert(for: fallbackName, message: message)
        }
    }

    private func validateImportURL(_ url: URL) throws -> URL {
        guard url.isFileURL else { throw SkinImportError.remoteURL }
        let standardized = url.standardizedFileURL
        let ext = standardized.pathExtension.lowercased()
        guard Self.allowedSkinExtensions.contains(ext) else {
            throw SkinImportError.unsupportedExtension(ext.isEmpty ? "unknown" : ext)
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: standardized.path)
            if let fileSize = attributes[.size] as? NSNumber,
               fileSize.intValue > Self.maxImportSizeBytes {
                throw SkinImportError.oversizedFile
            }
        } catch {
            throw SkinImportError.validationFailed(error.localizedDescription)
        }

        return standardized
    }

    private func ensureDestination(_ destination: URL, isWithin base: URL) throws {
        let resolvedDestination = destination.standardizedFileURL
        let resolvedBase = base.standardizedFileURL
        guard resolvedDestination.path.hasPrefix(resolvedBase.path) else {
            throw SkinImportError.copyFailed("Resolved path escapes user skins directory.")
        }
    }

    private func presentReplacementPrompt(for skinName: String) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = "Skin Already Exists"
        alert.informativeText = "A skin named \"\(skinName)\" already exists. Do you want to replace it?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            return await alert.beginSheetModal(for: window)
        } else {
            return alert.runModal()
        }
    }

    private func presentImportFailureAlert(for skinName: String, message: String) async {
        let alertMessage = "Could not import \"\(skinName)\": \(message)"
        _ = await presentAlert(
            title: "Import Failed",
            message: alertMessage,
            style: .critical
        )
    }

    @discardableResult
    private func presentAlert(title: String, message: String, style: NSAlert.Style) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            return await alert.beginSheetModal(for: window)
        } else {
            return alert.runModal()
        }
    }

    /// Show a system notification using modern UserNotifications framework.
    /// Falls back to NSAlert if bundle identifier is not configured (Xcode debug builds).
    private func showNotification(title: String, message: String) {
        guard Bundle.main.bundleIdentifier != nil else {
            AppLog.warn(.skin, "Bundle identifier is nil, falling back to NSAlert for notification")
            showNotificationAlert(title: title, message: message)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                AppLog.error(.skin, "Failed to show notification: \(error.localizedDescription)")
                Task { @MainActor in
                    self.showNotificationAlert(title: title, message: message)
                }
            }
        }
    }

    private func showNotificationAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }
}
