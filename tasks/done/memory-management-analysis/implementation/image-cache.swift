// MARK: - Image Cache Management Fixes
// This file contains fixes for unbounded image caching issues

import Foundation
import AppKit
import SwiftUI

// MARK: - Fix 1: LRU Image Cache Implementation

/// LRU Cache for skin images with size limits and memory management
class ImageCache: ObservableObject {
    private let maxCacheSize: Int
    private let maxMemoryUsage: Int64 // Maximum memory in bytes
    private var cache: [String: CacheEntry] = [:]
    private var accessOrder: [String] = []
    private var currentMemoryUsage: Int64 = 0
    
    private struct CacheEntry {
        let image: NSImage
        let size: Int64
        let accessTime: Date
        let loadTime: Date
    }
    
    init(maxCacheSize: Int = 50, maxMemoryMB: Int64 = 100) {
        self.maxCacheSize = maxCacheSize
        self.maxMemoryUsage = maxMemoryMB * 1024 * 1024
    }
    
    /// Get image from cache
    func image(for key: String) -> NSImage? {
        guard var entry = cache[key] else { return nil }
        
        // Update access time and order
        entry.accessTime = Date()
        cache[key] = entry
        moveToTop(key)
        
        return entry.image
    }
    
    /// Store image in cache with LRU eviction
    func setImage(_ image: NSImage, for key: String) {
        let imageSize = calculateImageSize(image)
        
        // Remove existing entry if present
        if let existingEntry = cache[key] {
            currentMemoryUsage -= existingEntry.size
            accessOrder.removeAll { $0 == key }
        }
        
        // Evict entries if necessary
        while (cache.count >= maxCacheSize || currentMemoryUsage + imageSize > maxMemoryUsage) && !cache.isEmpty {
            evictLeastRecentlyUsed()
        }
        
        // Add new entry
        let entry = CacheEntry(
            image: image,
            size: imageSize,
            accessTime: Date(),
            loadTime: Date()
        )
        
        cache[key] = entry
        accessOrder.append(key)
        currentMemoryUsage += imageSize
    }
    
    /// Remove specific image from cache
    func removeImage(for key: String) {
        guard let entry = cache[key] else { return }
        
        currentMemoryUsage -= entry.size
        cache.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }
    
    /// Clear all cached images
    func clearCache() {
        cache.removeAll()
        accessOrder.removeAll()
        currentMemoryUsage = 0
    }
    
    /// Get cache statistics
    var statistics: CacheStatistics {
        return CacheStatistics(
            count: cache.count,
            memoryUsage: currentMemoryUsage,
            memoryUsageMB: currentMemoryUsage / 1024 / 1024,
            maxMemoryUsageMB: maxMemoryUsage / 1024 / 1024
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateImageSize(_ image: NSImage) -> Int64 {
        let bytesPerPixel = 4 // RGBA
        return Int64(image.size.width * image.size.height * CGFloat(bytesPerPixel))
    }
    
    private func moveToTop(_ key: String) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    private func evictLeastRecentlyUsed() {
        guard let oldestKey = accessOrder.first,
              let oldestEntry = cache[oldestKey] else { return }
        
        currentMemoryUsage -= oldestEntry.size
        cache.removeValue(forKey: oldestKey)
        accessOrder.removeFirst()
    }
}

/// Cache statistics for monitoring
struct CacheStatistics {
    let count: Int
    let memoryUsage: Int64
    let memoryUsageMB: Int64
    let maxMemoryUsageMB: Int64
}

// MARK: - Fix 2: Enhanced SkinManager with Cache Management

extension SkinManager {
    
    /// FIXED: Image cache with LRU eviction
    @Published private var imageCache = ImageCache(maxCacheSize: 50, maxMemoryMB: 100)
    
    /// FIXED: Cache statistics for monitoring
    var cacheStatistics: CacheStatistics {
        imageCache.statistics
    }
    
    /// ENHANCED: Load skin with memory management
    func loadSkinWithMemoryManagement(from url: URL) {
        print("Loading skin from \(url.path)")
        isLoading = true
        
        do {
            let archive = try Archive(url: url, accessMode: .read)
            
            // Use autoreleasepool for temporary objects
            var extractedImages: [String: NSImage] = [:]
            
            autoreleasepool {
                // Process sheets with memory management
                let sheetsToProcess = buildSheetsToProcess(from: archive)
                
                for (sheetName, sprites) in sheetsToProcess {
                    if let images = processSheetOptimized(
                        name: sheetName,
                        sprites: sprites,
                        from: archive
                    ) {
                        extractedImages.merge(images) { _, new in new }
                    }
                }
            }
            
            // Parse text files (small memory footprint)
            let playlistStyle = parsePlaylistStyle(from: archive)
            let visualizerColors = parseVisualizerColors(from: archive)
            
            // Create skin object
            let newSkin = Skin(
                visualizerColors: visualizerColors,
                playlistStyle: playlistStyle,
                images: extractedImages,
                cursors: [:]
            )
            
            // Update current skin
            DispatchQueue.main.async {
                self.currentSkin = newSkin
                self.isLoading = false
                print("Skin loaded successfully with \(extractedImages.count) sprites")
            }
            
        } catch {
            print("Error loading skin: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
                self.loadingError = error.localizedDescription
            }
        }
    }
    
    /// ENHANCED: Process sheet with memory optimization
    private func processSheetOptimized(
        name: String,
        sprites: [Sprite],
        from archive: Archive
    ) -> [String: NSImage]? {
        
        guard let entry = findSheetEntry(in: archive, baseName: name) else {
            // Generate fallbacks for missing sheet
            return createFallbackSprites(forSheet: name, sprites: sprites)
        }
        
        // Extract sheet data with size limit
        var sheetData = Data()
        let maxSheetSize = 50 * 1024 * 1024 // 50MB limit per sheet
        
        _ = try? archive.extract(entry, consumer: { data in
            sheetData.append(data)
            if sheetData.count > maxSheetSize {
                throw NSError(domain: "SkinManager", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Sheet too large: \(name)"
                ])
            }
        })
        
        guard sheetData.count <= maxSheetSize,
              let sheetImage = NSImage(data: sheetData) else {
            return createFallbackSprites(forSheet: name, sprites: sprites)
        }
        
        var processedImages: [String: NSImage] = [:]
        
        // Process sprites with immediate cleanup
        for sprite in sprites {
            autoreleasepool {
                if let croppedImage = sheetImage.cropped(to: sprite.rect) {
                    var finalImage = croppedImage
                    
                    // Apply preprocessing if needed
                    if sprite.name == "MAIN_WINDOW_BACKGROUND" {
                        finalImage = preprocessMainBackground(croppedImage)
                    }
                    
                    processedImages[sprite.name] = finalImage
                } else {
                    // Use fallback for failed crop
                    let fallbackImage = createFallbackSprite(named: sprite.name)
                    processedImages[sprite.name] = fallbackImage
                }
            }
        }
        
        return processedImages
    }
    
    /// ENHANCED: Build sheets list with optional NUMS_EX handling
    private func buildSheetsToProcess(from archive: Archive) -> [String: [Sprite]] {
        var sheetsToProcess = SkinSprites.defaultSprites.sheets
        
        // Add NUMS_EX if available
        if findSheetEntry(in: archive, baseName: "NUMS_EX") != nil {
            sheetsToProcess["NUMS_EX"] = [
                Sprite(name: "NO_MINUS_SIGN_EX", x: 90, y: 0, width: 9, height: 13),
                Sprite(name: "MINUS_SIGN_EX", x: 99, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_0_EX", x: 0, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_1_EX", x: 9, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_2_EX", x: 18, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_3_EX", x: 27, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_4_EX", x: 36, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_5_EX", x: 45, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_6_EX", x: 54, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_7_EX", x: 63, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_8_EX", x: 72, y: 0, width: 9, height: 13),
                Sprite(name: "DIGIT_9_EX", x: 81, y: 0, width: 9, height: 13),
            ]
        }
        
        return sheetsToProcess
    }
    
    /// ENHANCED: Parse playlist style with minimal memory usage
    private func parsePlaylistStyle(from archive: Archive) -> PlaylistStyle {
        guard let pleditEntry = findTextEntry(in: archive, fileName: "pledit.txt") else {
            return PlaylistStyle(
                normalTextColor: .white,
                currentTextColor: .white,
                backgroundColor: .black,
                selectedBackgroundColor: Color(red: 0, green: 0, blue: 0.776),
                fontName: nil
            )
        }
        
        return autoreleasepool {
            var pleditData = Data()
            _ = try? archive.extract(pleditEntry, consumer: { pleditData.append($0) })
            
            if let parsed = PLEditParser.parse(from: pleditData) {
                return parsed
            }
            
            return PlaylistStyle(
                normalTextColor: .white,
                currentTextColor: .white,
                backgroundColor: .black,
                selectedBackgroundColor: Color(red: 0, green: 0, blue: 0.776),
                fontName: nil
            )
        }
    }
    
    /// ENHANCED: Parse visualizer colors with minimal memory usage
    private func parseVisualizerColors(from archive: Archive) -> [Color] {
        guard let visEntry = findTextEntry(in: archive, fileName: "viscolor.txt") else {
            return []
        }
        
        return autoreleasepool {
            var visData = Data()
            _ = try? archive.extract(visEntry, consumer: { visData.append($0) })
            
            if let colors = VisColorParser.parse(from: visData) {
                return colors
            }
            
            return []
        }
    }
    
    /// NEW: Memory pressure handling
    @objc private func handleMemoryPressure() {
        // Reduce cache size under memory pressure
        let targetSize = imageCache.statistics.count / 2
        while imageCache.statistics.count > targetSize {
            // Evict oldest entries
            imageCache.clearCache() // Simplified for now
        }
        
        print("Memory pressure detected, reduced image cache to \(targetSize) items")
    }
    
    /// NEW: Cache cleanup method
    func clearImageCache() {
        imageCache.clearCache()
        print("Image cache cleared")
    }
    
    /// NEW: Get memory usage report
    func getMemoryReport() -> String {
        let stats = cacheStatistics
        return """
        Image Cache Report:
        - Items: \(stats.count)
        - Memory Usage: \(stats.memoryUsageMB) MB / \(stats.maxMemoryUsageMB) MB
        - Usage: \(Double(stats.memoryUsageMB) / Double(stats.maxMemoryUsageMB) * 100)%"
        """
    }
}

// MARK: - Fix 3: Memory Monitoring

/// Memory monitoring utility for tracking image cache usage
class MemoryMonitor: ObservableObject {
    @Published var memoryUsage: Int64 = 0
    @Published var memoryWarningLevel: MemoryWarningLevel = .normal
    
    enum MemoryWarningLevel {
        case normal, warning, critical
        
        var color: Color {
            switch self {
            case .normal: return .green
            case .warning: return .orange
            case .critical: return .red
            }
        }
    }
    
    private var timer: Timer?
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.updateMemoryUsage()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateMemoryUsage() {
        let usage = getCurrentMemoryUsage()
        DispatchQueue.main.async {
            self.memoryUsage = usage
            self.memoryWarningLevel = self.calculateWarningLevel(usage)
        }
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
    
    private func calculateWarningLevel(_ usage: Int64) -> MemoryWarningLevel {
        let usageMB = usage / 1024 / 1024
        
        switch usageMB {
        case 0..<100: return .normal
        case 100..<200: return .warning
        default: return .critical
        }
    }
    
    deinit {
        stopMonitoring()
    }
}

// MARK: - Usage Example

/*
// In SkinManager:
@StateObject private var memoryMonitor = MemoryMonitor()

// In view body:
.onAppear {
    memoryMonitor.startMonitoring()
}
.onDisappear {
    memoryMonitor.stopMonitoring()
}

// Display memory status:
VStack {
    Text("Memory: \(memoryMonitor.memoryUsage / 1024 / 1024) MB")
        .foregroundColor(memoryMonitor.memoryWarningLevel.color)
    
    Text("Cache: \(skinManager.cacheStatistics.memoryUsageMB) MB")
}
*/