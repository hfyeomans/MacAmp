# Plan – O/I Buttons Review

1. **AppSettings Audit**
   - Inspect persistence strategy for new `timeDisplayMode` plus clutter-bar triggers to confirm @Observable compatibility and default migration path.
   - Verify didSet patterns align with rest of codebase and check for missing `UserDefaults` synchronization or thread annotations.

2. **WinampMainWindow Evaluation**
   - Review clutter bar UI wiring (O + I buttons) for state handling, reentrancy, and sprite selection.
   - Analyze `showOptionsMenu` implementation: lifecycle of `NSMenu`, menu item actions, `MenuItemTarget` bridging, coordinate calculations, scaling, and keyboard parity.
   - Inspect `sheet` binding for TrackInfo dialog plus `timeDisplayMode` usage in `buildTimeDisplay` and `onTapGesture` to ensure state updates propagate from AppSettings.

3. **AppCommands Integration**
   - Confirm keyboard shortcuts map to new functionality and interact safely with AppSettings/AudioPlayer.
   - Ensure triggers (show options menu / track info) coordinate correctly with main window presentation logic.

4. **TrackInfoView Review**
   - Assess metadata presentation, environment usage, dismissal, and stream vs local track coverage.
   - Check for missing data sanitization, placeholder handling, or concurrency issues.

5. **Synthesize Findings**
   - Map review criteria (code quality, SwiftUI patterns, memory/thread safety, persistence, NSMenu integration, error handling) to concrete recommendations.

