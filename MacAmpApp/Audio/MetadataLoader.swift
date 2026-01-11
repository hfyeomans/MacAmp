import Foundation
import AVFoundation
import CoreMedia

/// Loads audio and video metadata from media files.
/// Extracted from AudioPlayer as part of the Option C incremental refactoring.
///
/// Layer: Mechanism (pure utility, no state)
/// Responsibilities:
/// - Load track metadata (title, artist, duration) from audio files
/// - Load audio properties (channels, bitrate, sample rate)
/// - Load video metadata (resolution, format)
///
/// Design: nonisolated struct with static async methods.
/// Swift 6.2 ready: Methods can be marked @concurrent when available.
struct MetadataLoader {

    // MARK: - Result Types

    /// Metadata extracted from an audio track
    struct TrackMetadata {
        let title: String
        let artist: String
        let duration: TimeInterval
    }

    /// Technical audio properties
    struct AudioProperties {
        let channelCount: Int   // 1 = mono, 2 = stereo
        let bitrate: Int        // kbps
        let sampleRate: Int     // Hz

        static let `default` = AudioProperties(channelCount: 2, bitrate: 0, sampleRate: 0)
    }

    /// Video file metadata for display
    struct VideoMetadata {
        let filename: String
        let videoType: String
        let width: Int
        let height: Int

        /// Winamp-style display string: "filename (M4V): Video: 1280x720"
        var displayString: String {
            if width > 0 && height > 0 {
                return "\(filename) (\(videoType)): Video: \(width)x\(height)"
            } else {
                return "\(filename) (\(videoType)): Video: Unknown"
            }
        }
    }

    // MARK: - Track Metadata

    /// Load track metadata (title, artist, duration) from a media file.
    /// Returns fallback values if metadata cannot be read.
    static func loadTrackMetadata(from url: URL) async -> TrackMetadata {
        let asset = AVURLAsset(url: url)

        do {
            let metadata = try await asset.load(.commonMetadata)
            let durationCM = try await asset.load(.duration)

            let titleItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .commonIdentifierTitle
            ).first
            let artistItem = AVMetadataItem.metadataItems(
                from: metadata,
                filteredByIdentifier: .commonIdentifierArtist
            ).first

            let title = (try? await titleItem?.load(.stringValue)) ?? url.lastPathComponent
            let artist = (try? await artistItem?.load(.stringValue)) ?? "Unknown Artist"
            let duration = durationCM.seconds

            return TrackMetadata(title: title, artist: artist, duration: duration)
        } catch {
            AppLog.warn(.audio, "Failed to load metadata for \(url.lastPathComponent): \(error)")
            return TrackMetadata(
                title: url.lastPathComponent,
                artist: "Unknown",
                duration: 0.0
            )
        }
    }

    // MARK: - Audio Properties

    /// Load audio properties (channel count, bitrate, sample rate) from a media file.
    /// Returns nil if properties cannot be determined.
    static func loadAudioProperties(from url: URL) async -> AudioProperties? {
        let asset = AVURLAsset(url: url)

        do {
            let tracks = try await asset.load(.tracks)

            guard let audioTrack = tracks.first(where: { $0.mediaType == .audio }) else {
                return nil
            }

            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            let estimatedDataRate = try await audioTrack.load(.estimatedDataRate)

            var channelCount = 2
            var sampleRate = 0

            if let desc = formatDescriptions.first {
                if let streamDesc = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee {
                    channelCount = Int(streamDesc.mChannelsPerFrame)
                    sampleRate = Int(streamDesc.mSampleRate)
                    AppLog.debug(.audio, "Detected \(channelCount) channel(s) - \(channelCount == 1 ? "Mono" : "Stereo")")
                    AppLog.debug(.audio, "Sample rate: \(sampleRate) Hz (\(sampleRate/1000) kHz)")
                }
            }

            let bitrateKbps = Int(estimatedDataRate / 1000)
            AppLog.debug(.audio, "Bitrate: \(bitrateKbps) kbps")

            return AudioProperties(
                channelCount: channelCount,
                bitrate: bitrateKbps,
                sampleRate: sampleRate
            )
        } catch {
            AppLog.warn(.audio, "Failed to load audio properties: \(error)")
            return nil
        }
    }

    // MARK: - Video Metadata

    /// Load video metadata (resolution, format) from a video file.
    /// Returns metadata with unknown resolution if video track cannot be read.
    static func loadVideoMetadata(from url: URL) async -> VideoMetadata {
        let filename = url.deletingPathExtension().lastPathComponent
        let videoType = url.pathExtension.uppercased()

        do {
            let asset = AVURLAsset(url: url)
            let tracks = try await asset.load(.tracks)

            if let videoTrack = tracks.first(where: { $0.mediaType == .video }) {
                let naturalSize = try await videoTrack.load(.naturalSize)
                let width = Int(naturalSize.width)
                let height = Int(naturalSize.height)

                let metadata = VideoMetadata(
                    filename: filename,
                    videoType: videoType,
                    width: width,
                    height: height
                )
                AppLog.debug(.audio, "Video metadata: \(metadata.displayString)")
                return metadata
            }
        } catch {
            AppLog.warn(.audio, "Failed to load video metadata: \(error)")
        }

        // Fallback for errors or missing video track
        let metadata = VideoMetadata(
            filename: filename,
            videoType: videoType,
            width: 0,
            height: 0
        )
        AppLog.debug(.audio, "Video metadata (fallback): \(metadata.displayString)")
        return metadata
    }
}
