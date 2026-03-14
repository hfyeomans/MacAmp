# SwiftZipArchive

<p align="center">
  <img src="icon.png" alt="SwiftZipArchive icon" width="180" />
</p>

SwiftZipArchive is a Swift-first ZIP library for Apple platforms.
It is a rewrite of SSZipArchive's API surface in Swift, backed by `minizip-ng` C sources for ZIP format compatibility and encryption support.

## Features

- Create ZIP archives from files and directories
- Extract ZIP archives with overwrite control
- Password validation and password-protected extraction
- AES and PKWARE encryption support
- Nested ZIP extraction support
- Symlink-safe extraction controls (`symlinksValidWithin`)
- Delegate, progress, and completion callbacks
- Incremental ZIP writer API (`open`, `write...`, `close`)

## Requirements

- Swift 5.9+
- Xcode 15+
- iOS 15.5+
- macOS 10.15+
- tvOS 15.4+
- watchOS 8.4+
- visionOS 1.0+

## Installation (Swift Package Manager)

```swift
.package(url: "https://github.com/matt-minev/SwiftZipArchive.git", from: "1.0.0")
```

Then add the product:

```swift
.product(name: "SwiftZipArchive", package: "SwiftZipArchive")
```

## Quick Start

```swift
import SwiftZipArchive

let created = SwiftZipArchive.createZipFile(
    atPath: "/tmp/example.zip",
    withContentsOfDirectory: "/tmp/input"
)

let extracted = SwiftZipArchive.unzipFile(
    atPath: "/tmp/example.zip",
    toDestination: "/tmp/output"
)
```

## API Notes

- Primary type: `SwiftZipArchive`
- Primary delegate: `SwiftZipArchiveDelegate`
- Primary error: `SwiftZipArchiveError`
- NSError bridge domain: `SwiftZipArchiveErrorDomain`

## Examples

This repository includes runnable SwiftPM examples:

- `Examples/CreateArchive`: create an archive from a directory
- `Examples/ExtractArchive`: extract an archive with optional password

Run with:

```bash
swift run SwiftZipArchiveCreateExample <source-directory> <output-zip>
swift run SwiftZipArchiveExtractExample <zip-path> <output-directory> [password]
```

## Testing

```bash
swift test
```

Tests include parity-critical scenarios ported from the original Objective-C suite:

- Basic create/extract round trip
- Password-protected and AES extraction
- Password validation APIs
- Unicode filenames
- Path traversal sanitization
- Symlink safety controls
- Nested ZIP extraction
- Delegate/progress callback behavior

## Migration from SSZipArchive

- `SSZipArchive` is renamed to `SwiftZipArchive`
- `SSZipArchiveDelegate` is renamed to `SwiftZipArchiveDelegate`
- Swift error throwing is used where Objective-C APIs previously used `NSError**`
- Objective-C compatibility aliases are intentionally removed in this release

## Acknowledgements

SwiftZipArchive builds directly on the work of the original ZipArchive / SSZipArchive maintainers and contributors:

- Original project: [ZipArchive/ZipArchive](https://github.com/ZipArchive/ZipArchive)
- Original SSZipArchive naming and early implementation by [Sam Soffes](https://github.com/soffes)
- Ongoing ZIP engine foundations from [minizip-ng](https://github.com/zlib-ng/minizip-ng) by [nmoinvaz](https://github.com/nmoinvaz)
- Thanks to all contributors to both the original project and minizip-ng

## License

- SwiftZipArchive project code is licensed under MIT (`LICENSE.txt`)
- Bundled `minizip-ng` sources remain under the Zlib license (`CMinizip/minizip/LICENSE`)
