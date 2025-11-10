# Commit Strategy: Magnetic Docking Foundation

**Branch**: `feature/magnetic-docking-foundation`  
**Task**: Task 1 (Foundation for Video/Milkdrop)  
**Timeline**: 10-15 days  
**Commits**: ~15-20 atomic commits

---

## Commit Pattern

**Prefix Convention**:
- `feat:` - New functionality
- `refactor:` - Code restructuring
- `fix:` - Bug fixes
- `test:` - Test additions
- `docs:` - Documentation

**Atomic Principle**: Each commit is a logical, rollback-safe checkpoint

---

## Phase 1A: NSWindowController Setup (4-5 commits)

### Day 1-3 Commits

1. **WindowCoordinator foundation**
```bash
git add MacAmpApp/ViewModels/WindowCoordinator.swift
git commit -m "feat: Create WindowCoordinator singleton for multi-window management"
```

2. **Main window controller**
```bash
git add MacAmpApp/Windows/WinampMainWindowController.swift
git commit -m "feat: Create WinampMainWindowController (NSWindowController)"
```

3. **EQ and Playlist controllers**
```bash
git add MacAmpApp/Windows/WinampEqualizerWindowController.swift \
        MacAmpApp/Windows/WinampPlaylistWindowController.swift
git commit -m "feat: Create Equalizer and Playlist NSWindowControllers"
```

4. **MacAmpApp integration**
```bash
git add MacAmpApp/MacAmpApp.swift
git commit -m "refactor: Replace UnifiedDockView with WindowCoordinator"
```

5. **Delete unified view**
```bash
git rm MacAmpApp/Views/UnifiedDockView.swift
git commit -m "refactor: Remove UnifiedDockView (replaced by 3 NSWindows)"
```

---

## Phase 1B: Drag Regions (3-4 commits)

### Day 4-6 Commits

1. **WindowAccessor utility**
```bash
git add MacAmpApp/Utilities/WindowAccessor.swift
git commit -m "feat: Add WindowAccessor for SwiftUI → NSWindow bridge"
```

2. **Main window drag region**
```bash
git add MacAmpApp/Views/WinampMainWindow.swift
git commit -m "feat: Add custom titlebar drag region to Main window"
```

3. **EQ and Playlist drag regions**
```bash
git add MacAmpApp/Views/WinampEqualizerWindow.swift \
        MacAmpApp/Views/WinampPlaylistWindow.swift
git commit -m "feat: Add titlebar drag regions to Equalizer and Playlist"
```

4. **Drag testing & polish**
```bash
git add [any fixes]
git commit -m "fix: Improve drag region performance and smoothness"
```

---

## Phase 2: WindowSnapManager Integration (2-3 commits)

### Day 7-10 Commits

1. **Register windows**
```bash
git add MacAmpApp/ViewModels/WindowCoordinator.swift
git commit -m "feat: Register 3 windows with WindowSnapManager"
```

2. **Enable magnetic snapping**
```bash
git add [test files or docs]
git commit -m "feat: Enable 15px magnetic snapping for all windows"
```

3. **Testing & fixes**
```bash
git add [any snap detection fixes]
git commit -m "fix: Adjust cluster movement for edge cases"
```

---

## Phase 3: Delegate Multiplexer (1-2 commits)

### Day 11-12 Commits

1. **Create multiplexer**
```bash
git add MacAmpApp/Utilities/WindowDelegateMultiplexer.swift
git commit -m "feat: Create WindowDelegateMultiplexer for delegate conflicts"
```

2. **Integrate multiplexer**
```bash
git add MacAmpApp/ViewModels/WindowCoordinator.swift
git commit -m "feat: Integrate delegate multiplexer with all windows"
```

---

## Phase 4: Double-Size Coordination (2-3 commits)

### Day 13-15 Commits

1. **Migrate scaling to views**
```bash
git add MacAmpApp/Views/WinampMainWindow.swift \
        MacAmpApp/Views/WinampEqualizerWindow.swift \
        MacAmpApp/Views/WinampPlaylistWindow.swift
git commit -m "feat: Migrate double-size scaling to individual window views"
```

2. **Synchronized frame resizing**
```bash
git add MacAmpApp/ViewModels/WindowCoordinator.swift
git commit -m "feat: Synchronize NSWindow frame resizing for double-size mode"
```

3. **Testing & polish**
```bash
git add [any fixes]
git commit -m "fix: Maintain docked alignment during double-size toggle"
```

---

## Phase 5: Basic Persistence (1-2 commits)

### Day 16-17 Commits (Optional)

1. **AppSettings extension**
```bash
git add MacAmpApp/Models/AppSettings.swift
git commit -m "feat: Add window position persistence to AppSettings"
```

2. **WindowCoordinator save/restore**
```bash
git add MacAmpApp/ViewModels/WindowCoordinator.swift
git commit -m "feat: Implement window position save/restore"
```

---

## Milestone Tags

### Day 6: Three Windows Draggable
```bash
git tag -a v0.8.0-three-windows-draggable -m "Milestone: 3 independent NSWindows with custom drag regions"
```

### Day 10: Magnetic Snapping Works
```bash
git tag -a v0.8.0-magnetic-snapping -m "Milestone: WindowSnapManager integrated, 15px magnetic snapping functional"
```

### Day 14-15: Foundation Complete
```bash
git tag -a v0.8.0-foundation-complete -m "Foundation: 3-window magnetic docking complete

Infrastructure ready for Video/Milkdrop windows:
- NSWindowController architecture established
- WindowCoordinator managing 3 window singletons
- Custom drag regions for borderless windows
- WindowSnapManager integrated (15px magnetic snap)
- Cluster movement (group dragging) working
- Delegate multiplexer pattern in place
- Double-size mode synchronized across windows
- Basic window position persistence

Next: Resume milk-drop-video-support task to add Video and Milkdrop windows."
```

---

## Merge Strategy

### After Foundation Complete

```bash
# Ensure all tests passing
# Ensure no regressions
# Final commit
git add -A
git commit -m "docs: Foundation task completion summary"

# Merge to main
git checkout main
git merge feature/magnetic-docking-foundation --no-ff
git push origin main

# Push tags
git push origin --tags

# Delete feature branch
git branch -d feature/magnetic-docking-foundation
git push origin --delete feature/magnetic-docking-foundation

# Archive task
mv tasks/magnetic-docking-foundation tasks/done/

# Create completion summary
# Update READY_FOR_NEXT_SESSION.md
```

### Then Create Task 2 Branch

```bash
# Create new branch for Task 2
git checkout -b feature/video-milkdrop-windows

# Resume milk-drop-video-support task
# (Foundation is now in main branch, can build on it)
```

---

## Total Expected Commits

**Foundation Task**: ~15-20 atomic commits
- Phase 1A: 4-5 commits
- Phase 1B: 3-4 commits
- Phase 2: 2-3 commits
- Phase 3: 1-2 commits
- Phase 4: 2-3 commits
- Phase 5: 1-2 commits
- Polish/docs: 2-3 commits

**Milestone Tags**: 3 tags

---

**Branch Management**: Clean task-by-task branching  
**Atomic Commits**: Safe rollback at any checkpoint  
**Merge Strategy**: No-fast-forward for clear history
