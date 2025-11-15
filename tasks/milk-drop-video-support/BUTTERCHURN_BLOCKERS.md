# Butterchurn Integration Blockers (DEFERRED)

**Date:** 2025-11-14
**Status:** BLOCKED - External JavaScript files not loading in WKWebView
**Deferring to:** Future session after research

---

## What Works ✅

1. **WKWebView lifecycle** - Fixed NSHostingController issue
   - Window appears (`🟢 WinampMilkdropWindow: Window appeared`)
   - Content area appears (`🟢 WinampMilkdropWindow: Content area appeared`)
   - HTML loads successfully (`✅ Butterchurn: Loading HTML from ...`)

2. **Inline JavaScript execution** - Works!
   - Dark green background renders
   - Debug overlay shows "HTML Loaded ✓" and "JavaScript: Running ✓"
   - Inline `<script>` tags execute

3. **Entitlements** - JIT enabled
   - `com.apple.security.cs.allow-jit: true`
   - `com.apple.security.cs.allow-unsigned-executable-memory: true`

---

## What's Blocked ❌

**External JavaScript files don't load:**
- `<script src="butterchurn.min.js">` fails silently
- `<script src="butterchurnPresets.min.js">` fails silently
- `<script src="bridge.js">` fails silently

**Evidence:**
- Third line shows: "Butterchurn: Failed to load"
- No 🟡 yellow messages from bridge.js
- `butterchurn` global undefined in JavaScript

**Files ARE in the bundle:**
```
/MacAmp.app/Contents/Resources/Butterchurn/index.html ✓
/MacAmp.app/Contents/Resources/Butterchurn/butterchurn.min.js ✓
/MacAmp.app/Contents/Resources/Butterchurn/butterchurnPresets.min.js ✓
/MacAmp.app/Contents/Resources/Butterchurn/bridge.js ✓
/MacAmp.app/Contents/Resources/Butterchurn/test.html ✓
```

---

## Suspected Causes

1. **WKWebView local file restrictions**
   - WKWebView has strict security for `file://` URLs
   - Might not allow loading external JS from local files
   - Even with `allowingReadAccessTo:` directory

2. **Content Security Policy**
   - Added CSP: `default-src 'self' 'unsafe-inline' 'unsafe-eval' file: data: blob:`
   - Still not loading external files

3. **Xcode folder structure**
   - Tried: Individual files (yellow groups)
   - Tried: Folder reference (blue folder)
   - Both copy files to bundle correctly
   - Neither allows JS loading

---

## Attempted Solutions (All Failed)

1. ❌ Added files as yellow groups → Files in root Resources/
2. ❌ Added folder as blue reference → Files in Resources/Butterchurn/
3. ❌ Enabled JIT entitlements
4. ❌ Enabled unsigned executable memory
5. ❌ Added Content-Security-Policy meta tag
6. ❌ Multiple search paths in ButterchurnWebView.swift
7. ❌ Fixed NSHostingController lifecycle
8. ❌ Added debug logging throughout

---

## Alternative Approaches to Research

### Option A: Inline All JavaScript
- Embed butterchurn.min.js content directly in `<script>` tag
- Avoids external file loading entirely
- ~470KB of inline JavaScript (might work)

### Option B: Use NSBundle to load JS as strings
- Load .js files via Swift `Bundle.main.url`
- Inject as strings via `webView.evaluateJavaScript()`
- Bypasses WKWebView file loading restrictions

### Option C: Native Metal Renderer
- Abandon JavaScript approach entirely
- Implement visualization in Swift/Metal
- Much more work but native performance
- Would need to port Butterchurn's preset system

### Option D: Use projectM (C++ library)
- Open-source Milkdrop clone (C++)
- Can be compiled for macOS
- Bridge to Swift via Objective-C++
- Might be easier than full Metal rewrite

---

## Recommended Next Steps

1. **Research WKWebView local file loading**
   - Check Apple docs for file:// URL restrictions
   - Look for successful examples of local JS loading
   - Investigate loadHTMLString vs loadFileURL differences

2. **Try Option B (Bundle injection)**
   - Quick test: Load butterchurn.min.js as String
   - Inject via evaluateJavaScript before loading HTML
   - Might bypass file loading restrictions

3. **Evaluate native alternatives**
   - Research projectM viability for macOS
   - Estimate effort for Metal renderer
   - Compare with Butterchurn benefits

---

## Files Created

- `MacAmpApp/Resources/Butterchurn/index.html` (debug version)
- `MacAmpApp/Resources/Butterchurn/test.html` (minimal test)
- `MacAmpApp/Resources/Butterchurn/butterchurn.min.js` (238KB)
- `MacAmpApp/Resources/Butterchurn/butterchurnPresets.min.js` (230KB)
- `MacAmpApp/Resources/Butterchurn/bridge.js` (with debug logging)
- `MacAmpApp/Views/Windows/ButterchurnWebView.swift`
- `MacAmpApp/MacAmp.entitlements` (updated with JIT)

---

## Current State

**Milkdrop Window Status:**
- ✅ GEN.bmp chrome renders perfectly
- ✅ Window opens/closes with Ctrl+K
- ✅ Window persistence working
- ✅ Magnetic snapping working
- ⏸️ Butterchurn visualization DEFERRED
- ⏸️ "MILKDROP" text DEFERRED (needs dynamic GEN letter extraction)

**Next Session:**
- Try Option B (Bundle JS injection) - 30min effort
- If that fails, research projectM or native Metal
- Decision point: JavaScript vs Native rendering

---

**Last Updated:** 2025-11-14
**Session Time on Butterchurn:** ~2 hours (troubleshooting)
**Deferring to:** Future dedicated Butterchurn debug session
