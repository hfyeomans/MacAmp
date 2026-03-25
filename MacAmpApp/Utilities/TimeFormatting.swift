import Foundation

/// Shared time formatting for duration displays across playlist and track info views.
enum TimeFormatting {
    /// Format a duration in seconds as "M:SS" (e.g., 125.0 -> "2:05").
    static func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = max(0, Int(seconds))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
