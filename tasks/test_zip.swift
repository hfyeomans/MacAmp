import Foundation
import AppleArchive
import System

// Just testing if ArchiveByteStream.fileStream supports zip
let url = URL(fileURLWithPath: "test.zip")
// creating a dummy zip
let fm = FileManager.default
let data = "hello".data(using: .utf8)!
fm.createFile(atPath: "test.txt", contents: data)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
task.arguments = ["test.zip", "test.txt"]
try! task.run()
task.waitUntilExit()

guard let stream = ArchiveByteStream.fileStream(path: FilePath("test.zip"), mode: .readOnly, options: [], permissions: []) else {
    print("Cannot open stream")
    exit(1)
}
// AppleArchive primarily uses .aar. Can it read .zip natively via ArchiveStream? No, it uses Apple Archive format.
print("Stream opened")
