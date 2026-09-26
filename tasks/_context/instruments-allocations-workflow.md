# Instruments Allocations Workflow (macOS 26 / Xcode 16+)

> **Source of truth for in-repo Instruments leak checks.** Captured 2026-05-19 from Apple's "Analyze heap memory" WWDC 2024 session + Xcode 16 / Instruments docs. **Updated 2026-09-05** (Recorded-Types module name corrected to `MacAmp`; added the `xcrun heap` census gotcha). Modern UI differs from pre-macOS-15 walkthroughs (no post-recording "Statistics" tab; pre-recording config view is new).
>
> **Use cases:**
> - S3-2 `avplayer-native-video-dsp` Phase 2 todo 2.40 (`VideoTapContext` retain/release balance after `passRetained` ↔ `tapFinalize`)
> - Future S3-* tasks: stream-decoder lifecycle (S3-3 HLS, S3-4 OGG)
> - Phase 8 verification matrix execution

---

## Mental model: modern Instruments is two phases

| Phase | What you see | What you do |
|---|---|---|
| **A. Pre-recording config** | Big inspector page with Target / Recorder Settings / per-instrument config (Allocations, VM Tracker, Points of Interest) | Set target binary; pick recording mode; configure **Recorded Types** table (this is the modern equivalent of the old "post-recording Statistics filter") |
| **B. Recording** | Live timeline with the red Record button active | Reproduce the issue in your app |
| **C. Post-recording analysis** | Timeline at top + detail panel at bottom with a **jump bar** to switch views; **Lifespan filter dropdown** at bottom of window | Inspect persistent vs transient counts; mark generations; jump to call trees |

There is **no separate "Statistics" tab** anymore. Equivalent information now lives in the detail panel's default list view + the **Lifespan filter** dropdown.

---

## Phase A — Pre-recording configuration

### A1. Target section (top)

- **Device:** the Mac running the app.
- **Target:** `Launch` mode + pick the `.app` bundle.
  - For MacAmp: `/Users/hank/dev/src/MacAmp/build/DerivedDataDev/Build/Products/Debug/MacAmp.app`
- **Arguments / Environment Variables:** usually empty.
- **Working Directory:** Automatic.

### A2. Recorder Settings

- **Recording Mode:**
  - `Immediate` — process and display data live during recording. **Use this for interactive leak checks** so you can watch counts go up/down as you exercise the app.
  - `Deferred` — record raw events, process after stop. Lower overhead; use for performance traces or long runs. **Not what you want for a 5-clip leak check.**
- **Stop recording after** — set to a generous value (e.g. `12 hours`) so you control stop manually.

### A3. Allocations instrument config

- **All Allocations:**
  - `Discard unrecorded data upon stop` — leave checked (saves disk).
  - `Discard events for freed memory` — **leave unchecked** for leak checks; we *want* to see freed events to verify they happen.
  - `Only track VM allocations` — leave unchecked (we want heap, not VM).
- **Heap Allocations:**
  - `Record reference counts` — **CHECK THIS** if you suspect ARC bugs (`passRetained` / `release` imbalance). Adds overhead but shows every retain/release. **Required for `Unmanaged` lifecycle audits.**
  - `Identify virtual C++ objects` — leave checked (no harm).
  - `Enable NSZombie detection` — leave unchecked (don't want to extend object lifetime artificially during leak check).
- **Recorded Types** table — the modern filter. Default rows:
  - `*` Contains → Record (wildcard)
  - `NS` Has prefix → Ignore
  - `CF` Has prefix → Ignore
  - `Malloc` Has prefix → Ignore

  Rules evaluate top-to-bottom; later rules override earlier ones. For a class-specific test:
  - **Option 1 (simpler):** leave defaults. Filter to your class post-hoc using the detail panel's search field.
  - **Option 2 (smaller trace):** disable the wildcard `*` row, add a row `MacAmp.VideoTapContext` (Swift class name — your app prefix + class) → Has prefix → Record. Records *only* allocations of that class. Lighter trace, faster analysis.

    (Swift module name is the PRODUCT_NAME `MacAmp`, not the scheme name `MacAmpApp`; mangled symbols read `_$s6MacAmp…` — a `MacAmpApp.` filter matches nothing and yields a false PASS.)

  **For Swift classes, the type string is `<ModuleName>.<ClassName>`** — e.g. `MacAmp.VideoTapContext`. Foundation/ObjC classes don't get the prefix.

### A4. VM Tracker config

- **Snapshot:** `Manually` (don't take periodic snapshots; we'll trigger them).

### A5. Points of Interest

- `Exclude os_log messages` — check if your app is logging heavily; otherwise leave unchecked.

---

## Phase B — Recording

1. Click the **red Record button** in the top-left of the window. Instruments launches the target `.app`.
2. Reproduce the scenario (e.g. play 5 video clips).
3. Click **Stop** (square icon, same location as Record).

### Mark Generation (powerful for leak attribution)

While recording, you can click **"Mark Generation"** at specific points to bracket allocation events:
- Each generation captures all allocations created since the previous generation that **persist to end of trace**.
- Multiple generations let you see *which interval* introduced persistent growth.
- Workflow: hit Mark Generation → do action → hit Mark Generation → do next action → ...

For a 5-clip leak check: Mark Generation between each clip play. After Stop, generations B/C/D/E/F should each show 0 persistent allocations of your target class — if any generation shows N>0, that clip's playback failed to balance.

---

## Phase C — Post-recording analysis

### C1. The detail panel + jump bar

Below the timeline, the detail panel has a **jump bar in the middle** of its title strip — clicking it lets you switch views:
- **Allocations List** (default) — flat list of types with counts. **This is the legacy "Statistics" replacement.**
- **Call Trees** — hierarchical view of allocation backtraces. Use to find *where in code* allocations happen.
- **Allocations Summary** — high-level totals.

### C2. Lifespan filter (the key new control)

At the **bottom of the window**, there's a **Lifespan filter dropdown**:
- **"Created & Still Living"** — only allocations made during the selected time range that are *still alive* at the end. **This is the persistent count.** Filter to your class — if count > 0, it leaked.
- **"Created & Destroyed"** — only allocations made and freed during the range. **This is the transient count.**
- **"Created" / "Destroyed"** — allocation/free events alone.
- **"All"** — everything.

**The "Persistent" count semantic from old Instruments lives in the Lifespan dropdown now.**

### C3. Filter to your class

In the detail panel's search/filter field (top-right of the panel), type the class name — e.g. `VideoTapContext`. The list filters live.

### C4. Inspecting an allocation

Double-click a row → shows:
- All instances of that class with addresses
- Each instance's allocation backtrace (jump to source via double-click)
- Each instance's reference-count history (if `Record reference counts` was on) — every retain/release with caller

For `Unmanaged.passRetained` audits: enabling `Record reference counts` gives you a literal log of every `retain` and `release` for each instance. A balanced lifecycle shows `+1 (alloc)` then a matching `-1 (dealloc)`. An unbalanced one shows `+1 +1 -1` or similar — the extra retain is the leak.

---

## Recipe: 5-clip `VideoTapContext` leak check (S3-2 Phase 2)

**Target binary:** `/Users/hank/dev/src/MacAmp/build/DerivedDataDev/Build/Products/Debug/MacAmp.app`

**Pre-recording config (Phase A):**
1. Recording Mode: **Immediate**
2. Heap Allocations → **check "Record reference counts"**
3. Recorded Types — add row:
   - Type String: `MacAmp.VideoTapContext`
   - Match: `Contains` (or `Has prefix`)
   - Action: `Record`
   - (Leave the wildcard row enabled too — we want all allocations as background context; the `VideoTapContext` row is for emphasis.)

**Recording (Phase B):**
1. Hit Record. App launches.
2. Drag in clip 1 (`clapperboard-videos/1_mp4_441_stereo.mp4`); play to natural end (~3 s).
3. **Mark Generation** (in Instruments toolbar).
4. Repeat for clips 2-5.
5. After clip 5 ends, wait ~5 s for deferred deallocs.
6. Stop.

**Analysis (Phase C):**
1. In detail panel, switch jump bar to **Allocations List**.
2. Search field: `VideoTapContext`.
3. Lifespan filter (bottom of window): **"Created & Still Living"** for selected range = entire trace.
4. Expected: **0 rows** (or 0 count). Any positive count = leak.
5. Switch Lifespan filter to **"Created & Destroyed"**: expect 5 rows (one per clip).
6. Switch jump bar to **Allocations List**, Lifespan **"All"**, **Total** column: expect 5.

**Pass criteria:**
| Reading | Verdict |
|---|---|
| Created & Still Living = 0, Created & Destroyed = 5 | ✅ Pass. Retain/release balanced. |
| Created & Still Living = 5, Created & Destroyed = 0 | ❌ Total leak. `tapFinalize` never fires. |
| Created & Still Living = N (1 ≤ N < 5), Created & Destroyed = 5 - N | ❌ Partial leak. Bisect via generations B-F. |
| Created & Still Living = 0, Created & Destroyed ≠ 5 | ⚠ Played fewer/more clips than expected, or some clips didn't install a tap (audio track missing / format guard rejected). Re-check. |

**On leak: per-instance retain audit**
1. Switch Lifespan to **"Created & Still Living"**, search `VideoTapContext`.
2. Expand the row → shows the surviving instance(s) with addresses.
3. Click each instance → right pane shows backtrace + reference-count log.
4. Compare to a healthy (destroyed) instance: find the *extra retain* (e.g. an unexpected `Unmanaged.passRetained` site) or the *missing release* (e.g. `tapFinalize` never reached, or `Unmanaged.takeRetainedValue()` substituted with `takeUnretainedValue()`).

---

## Gotchas

1. **Modern recording mode is Deferred by default.** Change it to **Immediate** for interactive tests. (Apple's default optimizes for perf trace overhead; we don't care for a 5-clip run.)
2. **"Statistics" view is gone.** Same data lives in the default Allocations List + the Lifespan filter dropdown.
3. **Swift class type strings are `<ModuleName>.<ClassName>`.** Don't search for `VideoTapContext` alone in Recorded Types — `MacAmp.VideoTapContext` works better, or use Contains match. The module is `MacAmp` (PRODUCT_NAME), **not** `MacAmpApp` (the scheme) — a `MacAmpApp.` filter matches nothing and reads as a false PASS.
4. **TSan-linked binaries work fine for leak checks** — TSan changes performance, not allocation count semantics. Don't rebuild without TSan just for this test.
5. **The .app bundle name is `MacAmp.app`, not `MacAmpApp.app`** (product name vs scheme name divergence).
6. **`Record reference counts` is expensive** — only enable when investigating retain/release imbalance specifically. For pure "did it leak Y/N" checks, leave it off.
7. **Foundation classes don't show your app prefix.** `NSString`, `__NSCFConstantString`, `CFArray` — these are pre-filtered out by the default `NS`/`CF` Ignore rules. Only your own Swift/ObjC types show with the app-prefix convention.
8. **`xcrun heap $(pgrep -x MacAmp) | grep -i VideoTapContext`** is a fast live-instance census that needs no Instruments (Debug build; may need sudo).

---

## Sources

- WWDC 2024 — Analyze heap memory: https://developer.apple.com/videos/play/wwdc2024/10173/
- Profiling Memory Allocations In iOS With Instruments — Agnostic Development: https://www.agnosticdev.com/blog-entry/ios/profiling-memory-allocations-ios-instruments
- Measuring Your App's Memory Usage with Instruments — Swift Dev Journal: https://swiftdevjournal.com/measuring-your-apps-memory-usage-with-instruments/
- Apple Instruments Help (archive): https://developer.apple.com/library/archive/documentation/AnalysisTools/Conceptual/instruments_help-collection/Chapter/Chapter.html
