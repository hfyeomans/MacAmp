# MacAmp Documentation Index

**Last Updated:** 2025-10-12
**Purpose:** Central index of all documentation for easy navigation and session resumption

---

## 🎯 START HERE

### Primary Entry Points

| Document | Purpose | Status |
|----------|---------|--------|
| **SESSION_STATE.md** | Current session status, next steps, quick resume | ✅ Current |
| **TESTING_GUIDE.md** | Manual testing procedures and checklist | ✅ Current |
| **DOCUMENTATION_INDEX.md** | THIS FILE - Navigate all docs | ✅ Current |

---

## 📋 Current Session Documentation (2025-10-12)

### Session Management
- **SESSION_STATE.md** - Current status, commits, next steps
- **TESTING_GUIDE.md** - Comprehensive manual testing procedures
- **CRITICAL_FIXES_COMPLETE.md** - Summary of all 4 critical bug fixes

### Architecture & Design Insights
- **docs/ARCHITECTURE_REVELATION.md** - Mechanism vs Presentation layer understanding
- **docs/BASE_PLAYER_ARCHITECTURE.md** - Base player + skin overlay design
- **docs/winamp-skins-lessons.md** - Complete knowledge base (1,705 lines)
  - NUMBERS.bmp vs NUMS_EX.bmp explained
  - Bundle discovery (SPM vs Xcode)
  - Sprite fallback system
  - Common pitfalls
- **docs/WINAMP_SKIN_VARIATIONS.md** - Skin format variations reference

### Issue Tracking & Fixes
- **docs/ISSUE_FIXES_2025-10-12.md** - Detailed bug reports and solutions
  - Issue #1: Import crash
  - Issue #2: Digits not incrementing
  - Issue #3: Invisible volume thumbs
  - Issue #4: EQ slider colors

### Implementation Guides
- **docs/SpriteResolver-Architecture.md** - SpriteResolver system design (650 lines)
- **docs/SpriteResolver-Implementation-Summary.md** - Integration guide (300 lines)
- **docs/SpriteResolver-Visual-Guide.md** - Visual diagrams (450 lines)

### Slider Research & Fixes
- **SLIDER_RESEARCH.md** - Webamp slider implementation research
- **SLIDER_FIX_SUMMARY.md** - Frame-based background positioning
- **SLIDER_IMPLEMENTATION_COMPARISON.md** - Before/after comparison
- **SLIDER_LEGACY_CODE.md** - Notes on removed gradient code
- **SLIDER_TEST_PLAN.md** - Slider testing procedures

---

## 🔬 Research Documentation

### Winamp Skin Format Research
- **tasks/winamp-skin-research-2025.md** - Comprehensive webamp clone analysis (8,300+ words)
- **tasks/skin-loading-research/research.md** - Original skin loading research
- **tasks/skin-switching-plan/plan.md** - Original implementation plan
- **tasks/skin-switching-plan/implementation-roadmap.md** - Gemini's 4-phase roadmap

### Sprite Fallback System
- **tasks/sprite-fallback-system/README.md** - Fallback system overview
- **tasks/sprite-fallback-system/implementation.md** - Technical details
- **tasks/sprite-fallback-system/verification.md** - Testing guide

### SpriteResolver Architecture Investigation (2025-10-12) ✅ COMPLETED
**Purpose:** Investigation and fix of double digit rendering issue
**Result:** SOLVED via MAIN_WINDOW_BACKGROUND preprocessing
**Lifetime:** Long-term (permanent record of architecture solution)

- **tasks/sprite-resolver-architecture/README.md** - Investigation index
  - *Status:* ✅ RESOLVED - Preprocessing solution implemented
  - *Lifetime:* Permanent (historical reference)

- **SPRITERESOLVER_INTEGRATION_COMPLETE.md** - ⭐ Phase 1 & 2 summary
  - *Why:* Complete record of SpriteResolver integration achievement
  - *Lifetime:* Long-term (permanent achievement record)
  - *Content:* Architecture, discoveries, testing results, success criteria

### Phase 3: Slider BMP Frame Rendering (2025-10-12) ⚠️ IN PROGRESS
**Purpose:** Fix slider gradient rendering using skin BMP files
**Result:** Volume & Balance ✅ WORKING | EQ/Preamp ⚠️ PARTIAL
**Lifetime:** Long-term (critical implementation reference)

- **tasks/phase3-base-mechanism/VOLUME_BMP_SOLUTION.md** - ⭐⭐ CRITICAL REFERENCE
  - *Why:* Documents THE solution to BMP frame rendering (SwiftUI modifier order!)
  - *Lifetime:* Permanent (applies to all future sprite sheet rendering)
  - *Content:* Working code, modifier order, frame calculations, lessons learned
  - *Apply to:* Balance, EQ, Preamp, any future frame-based sprites

- **tasks/phase3-base-mechanism/plan.md** - Phase 3 implementation tracking
  - *Why:* Tracks progress, documents discoveries
  - *Lifetime:* Medium-term (until Phase 3 complete)

- **PHASE3_BRANCHING_STRATEGY.md** - Branch structure explanation
  - *Why:* Documents nested branch approach (Option A vs Option B)
  - *Lifetime:* Short-term (until branches merged)

- **CODEX_VOLUME_SLIDER_ANALYSIS.txt** - Debugging investigation prompt
  - *Why:* Led to discovering modifier order issue
  - *Lifetime:* Short-term (archive after Phase 3 complete)

---

## 📦 Archived Documentation (Reference Only)

### Previous Session States
- **archives/SWIFTUI-UI-DETAIL-FIXES-STATE.md** - Old state file
- **archives/GEMINI_STATE.md** - Gemini conversation history
- **archives/CODEX_CONTEXT_STATE.md** - Previous context
- **archives/AMP_STATE.md** - Historical state

### Previous Plans
- **archives/AMP_FIX_PLAN.md** - Old fix plans
- **archives/BUILD_ERRORS_FIX_PLAN.md** - Build error resolution
- **archives/DOCKING_FIX_PLAN.md** - Window docking fixes
- **archives/GEMINI_GLASS_PLAN.md** - Liquid Glass integration
- **archives/GEMINI_PLAN.md** - Previous Gemini plans
- **archives/PLAYLIST_ALIGNMENT_FIX_PLAN.md** - Playlist fixes
- **archives/CLAUDE_PLAN.md** - Previous Claude plans

### Obsolete Documentation
- **PHASE_1_SUCCESS.md** - Superseded by SESSION_STATE.md
- **CLAUDE_STATE.md** - Old session state
- **CLAUDE_UI_PLAN.md** - Old UI plans
- **CHANGES_SUMMARY.md** - Old change tracking
- **CRASH_FIX_SUMMARY.md** - Old crash fix docs
- **TITLE_BAR_TRANSPARENT.md** - Historical fix
- **state.md** - Very old state file

---

## 🎨 Implementation Files

### ✅ Integrated (2025-10-12) - COMPLETE
- **MacAmpApp/Models/SpriteResolver.swift** - Semantic sprite resolution (390 lines)
  - ✅ Added to Xcode project
  - ✅ Priority-based fallback (DIGIT_0_EX → DIGIT_0)
  - ✅ Full SemanticSprite enum (40+ sprite types)

- **MacAmpApp/Views/Components/SimpleSpriteImage.swift** - Dual-mode sprite rendering
  - ✅ Legacy mode: SimpleSpriteImage("DIGIT_0")
  - ✅ Semantic mode: SimpleSpriteImage(.digit(0))
  - ✅ Simplified direct rendering (no wrapper views)

- **MacAmpApp/Views/WinampMainWindow.swift** - Time display migration
  - ✅ Migrated to semantic sprites (.digit, .minusSign)
  - ✅ Uses background ":" from MAIN.BMP (not rendered)
  - ✅ Digits increment and blink correctly

- **MacAmpApp/ViewModels/SkinManager.swift** - Background preprocessing
  - ✅ preprocessMainBackground() blacks out static digits
  - ✅ Preserves static ":" from background
  - ✅ Works across all skin variants

*Status:* ✅ **Phase 1 & 2 COMPLETE** - Proof of concept successful!

### Example Code
- **MacAmpApp/Views/Components/TimeDisplayExample.swift** - Migration examples
  - ⚠️ Removed due to compilation errors
  - ✅ Concepts documented in architecture docs
  - ✅ Real implementation in WinampMainWindow.swift:257-311

---

## 🗂️ Documentation by Topic

### Skin System
**Essential Reading:**
1. docs/winamp-skins-lessons.md - Start here for complete understanding
2. docs/WINAMP_SKIN_VARIATIONS.md - Quick reference for skin differences
3. tasks/winamp-skin-research-2025.md - Deep dive into webamp implementation

**Issues & Solutions:**
4. docs/ISSUE_FIXES_2025-10-12.md - Bug fixes applied this session
5. CRITICAL_FIXES_COMPLETE.md - Fix summary

### Architecture
**Critical Insights:**
1. docs/ARCHITECTURE_REVELATION.md - **READ THIS!** Mechanism vs presentation
2. docs/BASE_PLAYER_ARCHITECTURE.md - Base player design principles
3. docs/SpriteResolver-Architecture.md - Proposed solution architecture

**Implementation Guides:**
4. docs/SpriteResolver-Implementation-Summary.md - How to integrate
5. docs/SpriteResolver-Visual-Guide.md - Visual diagrams

### Testing & Verification
1. TESTING_GUIDE.md - Manual testing checklist
2. SLIDER_TEST_PLAN.md - Slider-specific tests
3. tasks/sprite-fallback-system/verification.md - Fallback testing

### Research & Analysis
1. tasks/winamp-skin-research-2025.md - Webamp clone analysis
2. SLIDER_RESEARCH.md - Volume/EQ slider research
3. tasks/skin-loading-research/research.md - Skin loading mechanisms

---

## 📊 Key Metrics

### Documentation Statistics
- **Total Documents:** 40+ markdown files
- **Current Session:** 15 new/updated documents
- **Total Words:** ~50,000+ words of documentation
- **Gitignored:** 10 files (*.md pattern in .gitignore)
- **Committed:** SESSION_STATE.md, TESTING_GUIDE.md, docs/winamp-skins-lessons.md

### Code Changes
- **Commits This Session:** 7
- **Files Modified:** 12
- **Lines Added:** +738
- **Lines Removed:** -815
- **Net Change:** -77 lines (simpler code!)

---

## 🔍 Quick Reference Guide

### "Where do I find...?"

**Current status?**
→ SESSION_STATE.md

**How to test?**
→ TESTING_GUIDE.md

**Why skins aren't working?**
→ docs/ARCHITECTURE_REVELATION.md

**How sprite resolution should work?**
→ docs/SpriteResolver-Architecture.md

**What's NUMBERS.bmp vs NUMS_EX.bmp?**
→ docs/winamp-skins-lessons.md (search for "Two Number Systems")

**How did webamp implement sliders?**
→ SLIDER_RESEARCH.md

**What bugs were fixed?**
→ docs/ISSUE_FIXES_2025-10-12.md

**What's the plan for refactor?**
→ SESSION_STATE.md → "Next Session: Architectural Refactor"

---

## 🚀 Next Session Quick Start

### If You're Starting Fresh

1. **Read:** SESSION_STATE.md (current status)
2. **Read:** docs/ARCHITECTURE_REVELATION.md (critical insight)
3. **Check:** Git branch (should be on new refactor branch)
4. **Review:** docs/SpriteResolver-Architecture.md (solution design)
5. **Begin:** Implement SpriteResolver integration

### If You're Continuing Testing

1. **Follow:** TESTING_GUIDE.md
2. **Launch:** App from Xcode
3. **Test:** All 4 critical issues
4. **Report:** Findings in new session
5. **Then:** Begin refactor

---

## 📁 File Organization

### Root Level (Project Root)
```
MacAmp/
├── SESSION_STATE.md              ⭐ Start here
├── TESTING_GUIDE.md              ⭐ Testing procedures
├── DOCUMENTATION_INDEX.md        ⭐ This file
├── CRITICAL_FIXES_COMPLETE.md    ℹ️ Bug fix summary
├── SLIDER_*.md                   ℹ️ Slider research (5 files)
├── PHASE_1_SUCCESS.md            🗄️ Obsolete
└── ... (other legacy docs)
```

### docs/ Directory (Organized Documentation)
```
docs/
├── ARCHITECTURE_REVELATION.md           ⭐⭐ CRITICAL - Read first!
├── BASE_PLAYER_ARCHITECTURE.md          ⭐ Design principles
├── winamp-skins-lessons.md              📚 Complete knowledge base
├── WINAMP_SKIN_VARIATIONS.md            📚 Quick reference
├── ISSUE_FIXES_2025-10-12.md            🐛 Bug tracking
├── SpriteResolver-Architecture.md       🔧 Solution design
├── SpriteResolver-Implementation-Summary.md  🔧 Integration guide
└── SpriteResolver-Visual-Guide.md       🔧 Visual diagrams
```

### tasks/ Directory (Research & Planning)
```
tasks/
├── winamp-skin-research-2025.md         📖 Webamp analysis (8,300 words)
├── skin-loading-research/research.md    📖 Skin loading
├── skin-switching-plan/
│   ├── plan.md                          📋 Original plan
│   └── implementation-roadmap.md        📋 Gemini roadmap
└── sprite-fallback-system/
    ├── README.md                        🛡️ Fallback overview
    ├── implementation.md                🛡️ Technical details
    └── verification.md                  🛡️ Testing guide
```

### archives/ Directory (Historical Reference)
```
archives/
├── Previous session states (8 files)
└── Old planning documents (6 files)
```

---

## 🎯 Documentation Quality Levels

### ⭐⭐ CRITICAL - Must Read
- docs/ARCHITECTURE_REVELATION.md
- SESSION_STATE.md

### ⭐ IMPORTANT - Should Read
- docs/BASE_PLAYER_ARCHITECTURE.md
- docs/winamp-skins-lessons.md
- docs/SpriteResolver-Architecture.md
- TESTING_GUIDE.md

### 📚 REFERENCE - Read as Needed
- docs/WINAMP_SKIN_VARIATIONS.md
- docs/ISSUE_FIXES_2025-10-12.md
- SLIDER_RESEARCH.md
- tasks/winamp-skin-research-2025.md

### ℹ️ INFORMATIONAL - Context Only
- CRITICAL_FIXES_COMPLETE.md
- SLIDER_FIX_SUMMARY.md
- PHASE_1_SUCCESS.md

### 🗄️ ARCHIVED - Historical Only
- All files in archives/
- Old state.md, CLAUDE_STATE.md, etc.

---

## 🧹 Cleanup Recommendations

### Files Safe to Delete
```bash
# Obsolete/superseded
rm PHASE_1_SUCCESS.md
rm CLAUDE_STATE.md
rm CLAUDE_UI_PLAN.md
rm CHANGES_SUMMARY.md
rm CRASH_FIX_SUMMARY.md
rm state.md
rm TITLE_BAR_TRANSPARENT.md

# Keep in archives/ only
```

### Files to Keep
- SESSION_STATE.md ✅
- TESTING_GUIDE.md ✅
- DOCUMENTATION_INDEX.md ✅
- All docs/* files ✅
- All tasks/* files ✅
- All archives/* files ✅ (for history)

---

## 🔄 Git Status

### Committed & Pushed (This Session)
- SESSION_STATE.md (multiple updates)
- TESTING_GUIDE.md
- docs/winamp-skins-lessons.md
- Code fixes (6 Swift files)

### Gitignored (.gitignore: `*.md` except README.md)
- docs/*.md (all other docs)
- Root level .md files (except those committed with -f)
- This means most documentation is LOCAL ONLY

### Untracked (Not Committed)
- docs/ARCHITECTURE_REVELATION.md
- docs/BASE_PLAYER_ARCHITECTURE.md
- docs/ISSUE_FIXES_2025-10-12.md
- docs/SpriteResolver-*.md (3 files)
- CRITICAL_FIXES_COMPLETE.md
- SLIDER_*.md (5 files)
- tasks/sprite-fallback-system/* (3 files)
- MacAmpApp/Models/SpriteResolver.swift

**Note:** These exist locally but aren't in version control due to .gitignore

---

## 📝 Documentation Workflow

### When to Update Which File

**Every Session:**
- Update SESSION_STATE.md with latest status
- Update DOCUMENTATION_INDEX.md if new docs created

**When Testing:**
- Follow TESTING_GUIDE.md
- Document results in SESSION_STATE.md

**When Researching:**
- Create new file in tasks/ directory
- Add to DOCUMENTATION_INDEX.md
- Reference from SESSION_STATE.md

**When Fixing Bugs:**
- Document in docs/ISSUE_FIXES_[DATE].md
- Update SESSION_STATE.md with fix summary
- Add to DOCUMENTATION_INDEX.md

**When Changing Architecture:**
- Create design doc in docs/
- Update ARCHITECTURE_REVELATION.md
- Plan in SESSION_STATE.md → "Next Steps"

---

## 🎓 Learning Path

### New to MacAmp?
1. Read SESSION_STATE.md → Current status
2. Read docs/winamp-skins-lessons.md → Understanding skins
3. Read docs/ARCHITECTURE_REVELATION.md → Core problem
4. Read docs/SpriteResolver-Architecture.md → Solution design

### Need to Fix Something?
1. Read SESSION_STATE.md → Known issues
2. Read docs/ISSUE_FIXES_2025-10-12.md → Previous fixes
3. Read TESTING_GUIDE.md → How to verify
4. Check docs/winamp-skins-lessons.md → "Common Pitfalls"

### Planning Refactor?
1. Read docs/ARCHITECTURE_REVELATION.md → Why refactor needed
2. Read docs/BASE_PLAYER_ARCHITECTURE.md → Design principles
3. Read docs/SpriteResolver-Architecture.md → Proposed solution
4. Review tasks/winamp-skin-research-2025.md → Webamp patterns

---

## 🔗 External References

### Webamp Clone (Local Copy)
**Location:** `/Users/hank/dev/src/MacAmp/webamp_clone`

**Key Files:**
- `packages/webamp/js/skinParser.js` - Skin parsing
- `packages/webamp/js/components/MainWindow/Time.tsx` - Time display
- `packages/webamp/js/components/MainWindow/MainVolume.tsx` - Volume slider
- `packages/webamp/js/components/EqualizerWindow/Band.tsx` - EQ sliders
- `packages/webamp/css/main-window.css` - Styling layer

### Online Resources
- **Webamp Demo:** https://webamp.org
- **Internet Archive Skins:** https://skins.webamp.org (~70,000 skins)
- **Re-Amp (macOS):** https://re-amp.ru/skins/
- **Winamp Wiki:** http://wiki.winamp.com

---

## 🧭 Navigation Tips

### Finding Information Quickly

**Using grep:**
```bash
# Find all mentions of NUMBERS vs NUMS_EX
grep -r "NUMBERS.bmp\|NUMS_EX" docs/

# Find sprite resolution discussions
grep -r "SpriteResolver\|semantic sprite" docs/

# Find testing procedures
grep -r "test\|verify" TESTING_GUIDE.md
```

**Using this index:**
- Ctrl+F to search for keywords
- Jump to relevant section
- Follow links to specific files

**Using SESSION_STATE.md:**
- Always has "Quick Resume Commands"
- Links to relevant documentation
- Lists recent commits
- Shows current branch and status

---

## 📌 Critical Concepts

### Architecture Layers (From ARCHITECTURE_REVELATION.md)

**Webamp:**
```
Layer 1: MECHANISM (Timer, state)
Layer 2: BRIDGE (Semantic HTML: className="digit digit-0")
Layer 3: PRESENTATION (CSS maps to sprites)
```

**MacAmp Current:**
```
ALL LAYERS MIXED (hardcoded sprite names everywhere)
```

**MacAmp Target:**
```
Layer 1: MECHANISM (Timer, AudioPlayer)
Layer 2: BRIDGE (Semantic sprites: .digit(0))
Layer 3: PRESENTATION (SpriteResolver maps to actual sprites)
```

### Sprite Variants (From winamp-skins-lessons.md)

**Two Number Systems:**
- NUMBERS.bmp → DIGIT_0, DIGIT_1, ... (classic skins)
- NUMS_EX.bmp → DIGIT_0_EX, DIGIT_1_EX, ... (modern skins)

**Skins use ONE or the OTHER, rarely both!**

### Frame-Based Backgrounds (From SLIDER_RESEARCH.md)

**VOLUME.BMP:**
- 68×420px total
- 28 frames (each 15px tall)
- Show frame based on volume: `offset = -(frameIndex × 15px)`

---

## 🛠️ Practical Commands

### Building & Running
```bash
# SPM build
swift build

# Run SPM build
.build/debug/MacAmpApp

# Xcode build (via MCP)
# Use Xcode MCP tools

# Clean build
swift clean && swift build
```

### Documentation
```bash
# View session state
cat SESSION_STATE.md

# View documentation index
cat DOCUMENTATION_INDEX.md

# List all docs
find . -name "*.md" ! -path "*/webamp_clone/*" ! -path "*/.build/*"

# Search all docs for term
grep -r "YOUR_SEARCH_TERM" docs/ tasks/
```

### Git Workflow
```bash
# Check current branch
git branch

# View recent commits
git log --oneline -10

# Check what's changed
git status

# View diff of uncommitted changes
git diff
```

---

## 📅 Session History

### 2025-10-12 Session (This Session)

**Focus:** Fix Xcode build issues, implement Skins menu, fix critical bugs

**Commits:** 7
- 3d0597e: SPM bundle discovery
- 2f55e2d: Xcode bundle discovery + Skins menu
- 70aead9: Remove duplicate menus
- b4eb163: Documentation
- f821edc: Sprite aliasing + crash fix
- 7e8629d: Slider rendering + digit updates
- [Next]: Architecture revelation documentation

**Documentation Created:** 15+ files

**Key Discoveries:**
- Bundle discovery differences (SPM vs Xcode)
- NUMBERS.bmp vs NUMS_EX.bmp variations
- Mechanism vs presentation layer architecture
- Sprite resolution requirements

**Status:** Ready for PR, then fresh architectural refactor branch

---

## 🎯 Next Session Roadmap

### Immediate (Next Session - New Branch)

**Branch Name:** `feature/sprite-resolver-architecture`

**Goals:**
1. Integrate SpriteResolver into Xcode project
2. Update SimpleSpriteImage with semantic sprite support
3. Migrate time display as proof-of-concept
4. Test with Internet Archive skin
5. Verify digits increment correctly

**Success Criteria:**
- Time display works with ANY skin variant
- Internet Archive digits increment ✅
- Classic Winamp still works ✅
- Code is cleaner and more maintainable

### Medium Term (Following Sessions)

1. Migrate all transport buttons
2. Migrate play/pause indicators
3. Migrate sliders (volume, balance, EQ)
4. Remove sprite aliasing system (no longer needed)
5. Clean up fallback generation
6. Full testing across 10+ different skins

### Long Term (Future Enhancements)

1. Online skin browser (webamp.org integration)
2. Skin metadata display
3. Skin validation and repair tools
4. Skin editor/customization
5. User skin ratings and reviews

---

## 🏆 Session Achievements

### What Works Now ✅
- Both SPM and Xcode builds discover skins correctly
- Skins menu with keyboard shortcuts
- Skin import functionality
- No crashes on import (bundle identifier fixed)
- Sliders use actual skin backgrounds (not gradients)
- Clean menu structure (no duplicates)

### What Needs Work ⚠️
- Digits don't increment in Internet Archive skin
- Architecture tightly couples UI to specific sprite names
- No fallback to plain rendering without skins
- Sprite resolution hardcoded, not dynamic

### What's Ready to Integrate 🎨
- SpriteResolver system (fully designed and implemented)
- Complete documentation (2,000+ lines across 3 docs)
- Migration examples and guides
- Testing procedures

---

**Document Status:** Complete and Current
**Last Updated:** 2025-10-12, End of Session
**Next Update:** Start of architectural refactor session
**Maintainer:** MacAmp Development Team
