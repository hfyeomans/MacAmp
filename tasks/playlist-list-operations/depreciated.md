# Deprecated/Legacy Code: Playlist List Operations

> **Purpose:** Track any deprecated or legacy code removed during this task.

---

## Replaced Stub Methods (PlaylistWindowActions.swift)

Three `@objc` action methods previously showed placeholder alerts. All replaced with real implementations:

```swift
// BEFORE (removed):
@objc func newList(_ sender: NSMenuItem) {
    showAlert("New List", "Not supported yet")
}

@objc func saveList(_ sender: NSMenuItem) {
    showAlert("Save List", "Not supported yet")
}

@objc func loadList(_ sender: NSMenuItem) {
    showAlert("Load List", "Not supported yet")
}
```

## Replaced UTType Usage (PlaylistWindowActions.swift)

`presentAddFilesPanel` previously used `.playlist` which doesn't match `.m3u`/`.m3u8` on macOS:

```swift
// BEFORE (removed):
openPanel.allowedContentTypes = [.audio, .playlist, .movie]

// AFTER:
let m3uType = UTType(filenameExtension: "m3u") ?? .plainText
let m3u8Type = UTType(filenameExtension: "m3u8") ?? .plainText
openPanel.allowedContentTypes = [.audio, m3uType, m3u8Type, .movie]
```
