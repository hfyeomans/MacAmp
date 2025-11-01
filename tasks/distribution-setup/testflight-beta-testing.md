# TestFlight Beta Testing for MacAmp

## Executive Summary

TestFlight **fully supports macOS apps** (since November 2021) but requires **App Sandbox**, which means significant refactoring for MacAmp's file access patterns.

**Key Decision:** TestFlight vs Developer ID + Sparkle

---

## ✅ TestFlight Capabilities for macOS

### Supported Features
- ✅ Up to 10,000 external testers (+ 100 internal)
- ✅ 90-day build expiration
- ✅ Automatic updates via TestFlight app
- ✅ Built-in crash reporting
- ✅ Tester feedback with screenshots
- ✅ Multiple beta groups
- ✅ Custom URL schemes (`macamp://`)
- ✅ Network client access (internet radio streaming)

### Requirements
- ⚠️ **App Sandbox** (MANDATORY)
- ✅ Mac App Store Distribution certificate
- ✅ App Store Connect account
- ✅ Beta review for first external build

---

## ⚠️ Critical Consideration: App Sandbox Requirement

### What App Sandbox Means for MacAmp

**Current State (Non-Sandboxed):**
```swift
// Can directly access any file
let url = URL(fileURLWithPath: "/Users/username/Music/song.mp3")
let audioFile = try AVAudioFile(forReading: url)
```

**TestFlight State (Sandboxed):**
```swift
// MUST use open panel for user to select files
let openPanel = NSOpenPanel()
openPanel.allowedContentTypes = [.audio]
openPanel.allowsMultipleSelection = true

if openPanel.runModal() == .OK {
    for url in openPanel.urls {
        // Now you have security-scoped access to this file
        let audioFile = try AVAudioFile(forReading: url)
    }
}
```

### Required Changes for MacAmp

**1. Audio File Access**
- ❌ Remove: Direct file path access
- ✅ Add: `NSOpenPanel` for user to select music files
- ✅ Add: Security-scoped bookmark storage for persistent access
- ✅ Add: Entitlement: `com.apple.security.assets.music.read-only`

**2. Winamp Skin Loading**
- ❌ Remove: Direct .wsz file access from arbitrary locations
- ✅ Add: `NSOpenPanel` for user to select skin files
- ✅ Add: Security-scoped bookmarks for skin folder

**3. Playlist Files (M3U/PLS)**
- ✅ Already compatible (uses `NSOpenPanel`)

**4. Downloads Folder**
- ⚠️ Change entitlement from `com.apple.security.files.downloads.read-write`
- ✅ To: User-selected file access via dialogs

**5. Network Streaming**
- ✅ No changes needed
- ✅ `com.apple.security.network.client` works in sandbox

**6. Custom URL Scheme**
- ✅ No changes needed
- ✅ `macamp://` works in sandbox

---

## 📋 TestFlight Setup Process

### Prerequisites

1. **Apple Developer Account** ($99/year)
   - ✅ You have: Team ID AC3LGVEJJ8

2. **Mac App Store Distribution Certificate**
   - Create in Apple Developer Portal
   - Different from Developer ID Application certificate
   - Xcode can auto-manage this

3. **App Store Connect Access**
   - Create app record
   - Configure TestFlight settings

### Step-by-Step Setup

#### 1. Enable App Sandbox in Xcode

```xml
<!-- Add to MacAmp.entitlements -->
<key>com.apple.security.app-sandbox</key>
<true/>

<!-- Remove this (sandbox restricts it) -->
<key>com.apple.security.files.downloads.read-write</key>
<false/>

<!-- Add music library access -->
<key>com.apple.security.assets.music.read-only</key>
<true/>
```

#### 2. Refactor File Access Code

**Before (Non-Sandboxed):**
```swift
func loadTrack(path: String) {
    let url = URL(fileURLWithPath: path)
    audioPlayer.load(url: url)
}
```

**After (Sandboxed):**
```swift
func selectAndLoadTracks() {
    let openPanel = NSOpenPanel()
    openPanel.allowedContentTypes = [.audio, .mpeg4Audio, .mp3]
    openPanel.allowsMultipleSelection = true
    openPanel.canChooseDirectories = false

    if openPanel.runModal() == .OK {
        for url in openPanel.urls {
            // Store security-scoped bookmark for later access
            let bookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            if let bookmark = bookmark {
                UserDefaults.standard.set(bookmark, forKey: "track_\(url.lastPathComponent)")
            }

            audioPlayer.load(url: url)
        }
    }
}

func loadPreviouslySelectedTrack(bookmark: Data) {
    var isStale = false
    let url = try? URL(
        resolvingBookmarkData: bookmark,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
    )

    if let url = url {
        _ = url.startAccessingSecurityScopedResource()
        audioPlayer.load(url: url)
        url.stopAccessingSecurityScopedResource()
    }
}
```

#### 3. Create App Record in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Click **My Apps** → **+** → **New App**
3. Select **macOS** platform
4. Fill in app details:
   - **Name:** MacAmp
   - **Primary Language:** English
   - **Bundle ID:** com.hankyeomans.MacAmp
   - **SKU:** MacAmp-001
5. Click **Create**

#### 4. Archive and Upload to TestFlight

```bash
# In Xcode:
# 1. Select "Any Mac" as destination
# 2. Product → Archive
# 3. Wait for archive to complete
# 4. In Organizer, select archive
# 5. Click "Distribute App"
# 6. Choose "TestFlight & App Store"
# 7. Follow prompts (Xcode will sign and upload)
```

Or via command line:
```bash
# Archive
xcodebuild archive \
  -project MacAmpApp.xcodeproj \
  -scheme MacAmpApp \
  -configuration Release \
  -archivePath ~/Desktop/MacAmp.xcarchive

# Export for App Store
xcodebuild -exportArchive \
  -archivePath ~/Desktop/MacAmp.xcarchive \
  -exportPath ~/Desktop/MacAmp-TestFlight \
  -exportOptionsPlist ExportOptions-TestFlight.plist
```

**ExportOptions-TestFlight.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>AC3LGVEJJ8</string>
    <key>uploadSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
</dict>
</plist>
```

#### 5. Configure TestFlight in App Store Connect

1. Go to your app in App Store Connect
2. Click **TestFlight** tab
3. Wait for build to process (~10-30 minutes)
4. Add **Test Information:**
   - What to test
   - App description
   - Feedback email
   - Privacy policy URL (optional)
5. Create **Tester Groups:**
   - Internal: Your team members
   - External: Beta testers
6. Add testers by email

#### 6. Beta Review (First External Build Only)

- First build for external testers requires Apple review
- Usually faster than full App Store review (1-2 days)
- Subsequent builds don't require review

#### 7. Testers Install TestFlight App

1. Testers receive email invitation
2. Download **TestFlight app** from Mac App Store
3. Redeem invitation code
4. Install MacAmp from TestFlight
5. Updates delivered automatically

---

## 🔄 Alternative: Developer ID + Sparkle

### When to Choose This Path

**Use Developer ID + Sparkle if:**
- ❌ Don't want to sandbox MacAmp (yet)
- ✅ Want full file system access
- ✅ Distributing outside Mac App Store
- ✅ Need faster beta iteration
- ❌ Don't plan App Store release soon

### Setup Process

#### 1. Install Sparkle Framework

```bash
# Using Swift Package Manager
# In Xcode: File → Add Packages
# URL: https://github.com/sparkle-project/Sparkle
# Version: 2.6.0 or later
```

#### 2. Configure Sparkle

**Info.plist:**
```xml
<key>SUFeedURL</key>
<string>https://yourdomain.com/macamp/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer> <!-- Check daily -->
```

#### 3. Generate EdDSA Key Pair

```bash
# Sparkle includes generate_keys tool
./bin/generate_keys

# Save private key securely (for signing updates)
# Add public key to Info.plist
```

#### 4. Create Appcast XML

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>MacAmp Updates</title>
        <link>https://yourdomain.com/macamp/appcast.xml</link>
        <description>MacAmp update feed</description>
        <language>en</language>
        <item>
            <title>Version 1.0.1 Beta</title>
            <sparkle:releaseNotesLink>https://yourdomain.com/macamp/releasenotes.html</sparkle:releaseNotesLink>
            <pubDate>Fri, 24 Oct 2025 12:00:00 +0000</pubDate>
            <enclosure
                url="https://yourdomain.com/macamp/downloads/MacAmp-1.0.1.dmg"
                sparkle:version="1.0.1"
                sparkle:shortVersionString="1.0.1"
                length="50000000"
                type="application/octet-stream"
                sparkle:edSignature="SIGNATURE_HERE"
            />
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
        </item>
    </channel>
</rss>
```

#### 5. Sign and Upload Update

```bash
# Sign the DMG
./bin/sign_update MacAmp-1.0.1.dmg

# Upload to your server
scp MacAmp-1.0.1.dmg user@server:/path/to/downloads/
scp appcast.xml user@server:/path/to/appcast.xml
```

#### 6. Distribute to Beta Testers

**Options:**
- Email DMG directly
- Host on website with beta signup
- Use GitHub Releases (public or private)
- Share via Dropbox/Google Drive

---

## 📊 Comparison Matrix

| Aspect | TestFlight | Developer ID + Sparkle |
|--------|-----------|------------------------|
| **Setup Time** | 4-6 hours (first time) | 2-3 hours |
| **Sandbox Required** | Yes (mandatory) | No |
| **Tester Management** | Excellent (built-in) | Manual (email list) |
| **Max Testers** | 10,000 | Unlimited |
| **Auto Updates** | Built-in | Via Sparkle |
| **Crash Reports** | Built-in | Need to add |
| **Feedback Collection** | Built-in | Need to add |
| **Build Distribution** | Automatic | Manual upload |
| **Prepares for App Store** | Yes | No |
| **File Access** | Limited (dialogs) | Full access |
| **Cost** | $99/year (dev account) | $0 (+ hosting) |
| **Review Process** | First build only | None |
| **Certificate** | App Store Distribution | Developer ID |
| **Notarization** | Not required | Required |

---

## 🎯 Recommendation for MacAmp

### Strategic Decision Framework

**Choose TestFlight if:**
1. ✅ Planning eventual Mac App Store release
2. ✅ Want professional beta testing infrastructure
3. ✅ Willing to invest 8-12 hours in sandboxing refactoring
4. ✅ Want Apple-managed crash reports and feedback
5. ✅ Need to manage many beta testers (100+)

**Choose Developer ID + Sparkle if:**
1. ✅ Committed to independent distribution
2. ✅ Want to avoid sandboxing complexity
3. ✅ Need full file system access flexibility
4. ✅ Want faster iteration on beta builds
5. ✅ Smaller beta tester group (<100)

### Recommended Path

**Phase 1: Developer ID + Sparkle (Now → v1.0)**
- ✅ Keep current non-sandboxed architecture
- ✅ Implement Sparkle for auto-updates
- ✅ Use GitHub Releases for beta distribution
- ✅ Focus on feature development
- ✅ Build user base with flexible file access

**Phase 2: Consider TestFlight (Post v1.0)**
- ⏸️ Evaluate user feedback on file access patterns
- ⏸️ Assess interest in App Store distribution
- ⏸️ If App Store makes sense, create sandboxed version
- ⏸️ Run parallel TestFlight beta for App Store build

**Rationale:**
- MacAmp's current architecture benefits from non-sandboxed file access
- Classic Winamp users expect direct file system access
- Sandboxing can be added later if App Store distribution becomes strategic
- Developer ID + Sparkle is the standard for independent macOS apps

---

## 🚀 Quick Start: Sparkle Implementation

### Estimated Time: 2-3 hours

#### 1. Add Sparkle Package

```swift
// In Xcode: File → Add Packages
// URL: https://github.com/sparkle-project/Sparkle
// Version: 2.6.4 (latest stable)
```

#### 2. Initialize in AppDelegate

```swift
import Sparkle

@main
struct MacAmpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // ... existing windows
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var updaterController: SPUStandardUpdaterController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
}
```

#### 3. Add Menu Item

```swift
.commands {
    CommandGroup(after: .appInfo) {
        CheckForUpdatesView(updater: updaterController.updater)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel

    init(updater: SPUUpdater) {
        checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}
```

#### 4. Configure Info.plist

```xml
<key>SUFeedURL</key>
<string>https://yourdomain.com/macamp/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>GENERATE_WITH_sparkle_generate_keys</string>
<key>SUEnableAutomaticChecks</key>
<true/>
```

#### 5. Generate Keys

```bash
# Download Sparkle tools
curl -L -O https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz
tar -xf Sparkle-2.6.4.tar.xz

# Generate EdDSA keys
./bin/generate_keys

# Copy public key to Info.plist
# KEEP PRIVATE KEY SECRET (for signing releases)
```

#### 6. Test Locally

```bash
# Build release version
xcodebuild -project MacAmpApp.xcodeproj -scheme MacAmpApp -configuration Release

# Run and check for updates
# Sparkle will check your appcast URL
```

---

## 📝 Next Steps

### For TestFlight Path:
1. [ ] Create sandboxed branch: `git checkout -b feature/app-sandbox`
2. [ ] Enable App Sandbox in Xcode
3. [ ] Refactor file access to use `NSOpenPanel`
4. [ ] Implement security-scoped bookmark storage
5. [ ] Test thoroughly with restricted file access
6. [ ] Create App Store Connect app record
7. [ ] Archive and upload first build
8. [ ] Submit for beta review

### For Sparkle Path (Recommended):
1. [ ] Add Sparkle via Swift Package Manager
2. [ ] Generate EdDSA keys
3. [ ] Configure Info.plist with feed URL
4. [ ] Create initial appcast.xml
5. [ ] Set up hosting for appcast and DMG files
6. [ ] Test update mechanism locally
7. [ ] Create GitHub Release for beta 1
8. [ ] Invite beta testers via email

---

## 📚 Resources

**TestFlight:**
- [Apple Developer - TestFlight](https://developer.apple.com/testflight/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Sandboxing Your Mac App](https://developer.apple.com/documentation/security/app_sandbox)

**Sparkle:**
- [Sparkle Project](https://sparkle-project.org/)
- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [GitHub Repository](https://github.com/sparkle-project/Sparkle)

**Beta Distribution:**
- [GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [Security-Scoped Bookmarks](https://developer.apple.com/documentation/security/app_sandbox/accessing_files_with_security-scoped_bookmarks)

---

**Decision Made:** ✅ Developer ID + Sparkle (Phase 1)
**Rationale:** Maintain flexibility, faster iteration, standard for indie macOS apps
**Future:** Consider TestFlight when/if App Store distribution becomes strategic
