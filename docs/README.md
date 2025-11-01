# MacAmp Documentation Hub

**Last Updated:** 2025-11-01
**Documentation Version:** 2.0.0

---

## 🎯 Quick Navigation

### For New Developers
1. **Start Here:** [MACAMP_ARCHITECTURE_GUIDE.md](MACAMP_ARCHITECTURE_GUIDE.md) - Complete 2,300+ line architectural reference
2. **Code Patterns:** [IMPLEMENTATION_PATTERNS.md](IMPLEMENTATION_PATTERNS.md) - Practical patterns and examples
3. **Sprite System:** [SPRITE_SYSTEM_COMPLETE.md](SPRITE_SYSTEM_COMPLETE.md) - Semantic sprite resolution

### For Active Development
- **Build & Deploy:** [RELEASE_BUILD_GUIDE.md](RELEASE_BUILD_GUIDE.md)
- **Skin Support:** [WINAMP_SKIN_VARIATIONS.md](WINAMP_SKIN_VARIATIONS.md)
- **Code Signing:** [CODE_SIGNING_FIX.md](CODE_SIGNING_FIX.md)

---

## 📚 Primary Documentation (November 2025)

### 🏗️ Architecture & Design

| Document | Status | Description | Lines |
|----------|--------|-------------|-------|
| **[MACAMP_ARCHITECTURE_GUIDE.md](MACAMP_ARCHITECTURE_GUIDE.md)** | ✅ NEW | **Complete architectural reference** - Three-layer architecture, dual audio backends, state management, SwiftUI patterns, internet radio, Swift 6 migration. The definitive technical guide. | 2,347 |
| **[IMPLEMENTATION_PATTERNS.md](IMPLEMENTATION_PATTERNS.md)** | ✅ NEW | **Practical code patterns** - State management, UI components, audio processing, async/await, error handling, testing, migration guides, anti-patterns | 847 |
| **[SPRITE_SYSTEM_COMPLETE.md](SPRITE_SYSTEM_COMPLETE.md)** | ✅ NEW | **Consolidated sprite documentation** - Semantic sprites, resolution algorithm, fallback generation, skin compatibility, integration patterns | 812 |

### 🔨 Build & Distribution

| Document | Status | Description |
|----------|--------|-------------|
| [RELEASE_BUILD_GUIDE.md](RELEASE_BUILD_GUIDE.md) | ✅ CURRENT | Complete guide for building, signing, and notarizing |
| [CODE_SIGNING_FIX.md](CODE_SIGNING_FIX.md) | ✅ CURRENT | Solutions for code signing issues |
| [CODE_SIGNING_FIX_DIAGRAM.md](CODE_SIGNING_FIX_DIAGRAM.md) | ✅ CURRENT | Visual diagram of signing process |

### 🎨 Skin System

| Document | Status | Description |
|----------|--------|-------------|
| [WINAMP_SKIN_VARIATIONS.md](WINAMP_SKIN_VARIATIONS.md) | ✅ CURRENT | Comprehensive skin format documentation |

---

## 📦 Superseded Documentation

The following documents have been superseded by the new comprehensive guides above:

### Replaced by MACAMP_ARCHITECTURE_GUIDE.md:
- `ARCHITECTURE_REVELATION.md` - Previous architecture doc (now integrated and expanded)
- `BASE_PLAYER_ARCHITECTURE.md` - Historical mechanism exploration

### Replaced by SPRITE_SYSTEM_COMPLETE.md:
- `SpriteResolver-Architecture.md` - Partial sprite documentation
- `SpriteResolver-Implementation-Summary.md` - Implementation details
- `SpriteResolver-Visual-Guide.md` - Visual examples
- `semantic-sprites/` directory - Phase 4 investigation

### Historical Implementation Docs:
- `ISSUE_FIXES_2025-10-12.md` - October bug fixes
- `title-bar-*.md` - Title bar customization
- `position-slider-*.md` - Slider fixes
- `docking-duplication-cleanup.md` - Window docking
- `winamp-skins-lessons.md` - Early skin insights

---

## 🗂️ Documentation Organization

```
docs/
├── README.md                           # This file - Navigation hub
│
├── 🆕 Primary References (November 2025)
├── MACAMP_ARCHITECTURE_GUIDE.md       # Complete architecture (2,347 lines)
├── IMPLEMENTATION_PATTERNS.md         # Code patterns (847 lines)
├── SPRITE_SYSTEM_COMPLETE.md          # Sprite system (812 lines)
│
├── Build & Distribution
├── RELEASE_BUILD_GUIDE.md
├── CODE_SIGNING_FIX.md
├── CODE_SIGNING_FIX_DIAGRAM.md
│
├── Skin Documentation
├── WINAMP_SKIN_VARIATIONS.md
│
└── Archive/ (historical docs)
    ├── ARCHITECTURE_REVELATION.md
    ├── BASE_PLAYER_ARCHITECTURE.md
    ├── SpriteResolver-*.md
    ├── semantic-sprites/
    └── [implementation fixes]
```

---

## 📖 Reading Paths

### Path 1: Understanding the Architecture (3-4 hours)
1. **MACAMP_ARCHITECTURE_GUIDE.md** - Sections 1-4 (Overview and core concepts)
2. **IMPLEMENTATION_PATTERNS.md** - State Management section
3. **MACAMP_ARCHITECTURE_GUIDE.md** - Sections 5-9 (Deep implementation)

### Path 2: Contributing Code (2 hours)
1. **IMPLEMENTATION_PATTERNS.md** - Full document
2. **MACAMP_ARCHITECTURE_GUIDE.md** - Quick Reference section
3. **SPRITE_SYSTEM_COMPLETE.md** - Integration section

### Path 3: Fixing Issues (1 hour)
1. **MACAMP_ARCHITECTURE_GUIDE.md** - Common Pitfalls section
2. **IMPLEMENTATION_PATTERNS.md** - Anti-Patterns section
3. **CODE_SIGNING_FIX.md** - If build issues

---

## 🔍 Document Status Legend

- ✅ **CURRENT** - Accurate and actively maintained
- 🆕 **NEW** - Created November 2025, comprehensive coverage
- 📦 **ARCHIVE** - Historical reference, superseded
- ❌ **OBSOLETE** - Should be removed

---

## 🚀 Key Insights from New Documentation

### From MACAMP_ARCHITECTURE_GUIDE.md:
- **Dual Audio Backend**: Why MacAmp needs both AVAudioEngine and AVPlayer
- **PlaybackCoordinator Pattern**: Orchestrating incompatible audio systems
- **Three-Layer Architecture**: Mechanism → Bridge → Presentation separation
- **Swift 6 Migration**: Complete @Observable adoption with @MainActor safety

### From IMPLEMENTATION_PATTERNS.md:
- **State Management**: @Observable vs ObservableObject patterns
- **Async/Await**: Modern Swift concurrency in practice
- **Testing Patterns**: Mock injection and async test helpers
- **Migration Guides**: Step-by-step modernization

### From SPRITE_SYSTEM_COMPLETE.md:
- **Semantic Resolution**: How any skin works with MacAmp
- **Fallback Generation**: Never crashes on missing sprites
- **Performance**: Intelligent caching strategies
- **Integration**: Clean component APIs

---

## 📝 Documentation Standards

### When Adding Documentation:
1. **Comprehensive Guides** (1000+ lines): Major architectural references
2. **Implementation Docs** (500-1000 lines): Specific system documentation
3. **Quick References** (<500 lines): Troubleshooting and fixes

### Document Headers Must Include:
```markdown
# Title

**Version:** X.Y.Z
**Date:** YYYY-MM-DD
**Status:** CURRENT | ARCHIVE | OBSOLETE
**Purpose:** Clear one-line description
```

### Quality Metrics:
- Include real code from actual files
- Provide file:line references where applicable
- Use ASCII diagrams for architecture
- Include "Why" explanations, not just "What"
- Add practical examples from the codebase

---

## 🔧 Maintenance Actions

### Recommended Archival:
```bash
# Create archive directory
mkdir -p /Users/hank/dev/src/MacAmp/docs/archive

# Move superseded documents
mv ARCHITECTURE_REVELATION.md archive/
mv BASE_PLAYER_ARCHITECTURE.md archive/
mv SpriteResolver-*.md archive/
mv semantic-sprites/ archive/
mv *-implementation.md archive/
mv *-summary.md archive/
```

### Keep in Main docs/:
- This README.md
- MACAMP_ARCHITECTURE_GUIDE.md (NEW)
- IMPLEMENTATION_PATTERNS.md (NEW)
- SPRITE_SYSTEM_COMPLETE.md (NEW)
- RELEASE_BUILD_GUIDE.md
- CODE_SIGNING_FIX*.md
- WINAMP_SKIN_VARIATIONS.md

---

## 📊 Documentation Metrics

| Category | Documents | Total Lines | Status |
|----------|-----------|-------------|---------|
| New Comprehensive Guides | 3 | 4,006 | ✅ Production |
| Build Documentation | 3 | ~500 | ✅ Current |
| Skin Documentation | 1 | ~400 | ✅ Current |
| Superseded/Archive | 15+ | ~3,000 | 📦 Historical |

**Total Active Documentation:** ~5,000 lines of current, comprehensive documentation

---

## 🎯 Next Steps

For developers joining the project:
1. Read **MACAMP_ARCHITECTURE_GUIDE.md** first (allow 2-3 hours)
2. Review **IMPLEMENTATION_PATTERNS.md** for coding standards
3. Reference **SPRITE_SYSTEM_COMPLETE.md** when working with UI

For maintainers:
1. Archive superseded documentation
2. Update this README when adding new docs
3. Ensure new features update relevant guides

---

*Documentation Hub Version: 2.0.0 | Last Updated: 2025-11-01*