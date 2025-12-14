import Foundation
import OSLog

enum LogCategory: String {
    case general
    case window
    case audio
    case playback
    case skin
    case ui
}

struct AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.macamp.app"

    private static func logger(for category: LogCategory) -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    static func debug(_ category: LogCategory, _ message: @autoclosure () -> String) {
#if DEBUG
        let msg = message()
        logger(for: category).debug("\(msg, privacy: .public)")
#endif
    }

    static func info(_ category: LogCategory, _ message: @autoclosure () -> String) {
#if DEBUG
        let msg = message()
        logger(for: category).info("\(msg, privacy: .public)")
#endif
    }

    static func error(_ category: LogCategory, _ message: @autoclosure () -> String) {
        let msg = message()
        logger(for: category).error("\(msg, privacy: .public)")
    }

    static func warn(_ category: LogCategory, _ message: @autoclosure () -> String) {
        let msg = message()
        logger(for: category).warning("\(msg, privacy: .public)")
    }
}
