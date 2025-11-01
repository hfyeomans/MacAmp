# Todo

- [x] Restore a `Task { @MainActor … }` hop (or shared helper) inside the ADD menu `NSOpenPanel` completion before mutating `audioPlayer`.
- [x] Deduplicate the ADD menu and toolbar file-picker code paths to avoid future divergence.
- [ ] Re-test (manual or via QA) long MP3 imports through the ADD menu after the fix to confirm the AVAudioFile warning no longer appears.
