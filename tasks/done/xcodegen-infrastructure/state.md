# State: XcodeGen Infrastructure

## Current Status: COMPLETE

## Summary

Migrated from manually-maintained `MacAmpApp.xcodeproj/project.pbxproj` to XcodeGen-generated project.

### What Changed
- `project.yml` updated with complete config (signing, entitlements, swift-atomics, test target)
- `project.yml` un-gitignored (committed to git as source of truth)
- `MacAmpApp.xcodeproj/` added to `.gitignore` (generated, never committed)
- `MacAmpApp.xcodeproj/` removed from git tracking (`git rm -r --cached`)
- CLAUDE.md, AGENTS.md, GEMINI.md updated with `xcodegen generate` workflow
- BUILDING_RETRO_MACOS_APPS_SKILL.md updated (Lesson #25 xcodeproj section)

### Verification
- `xcodegen generate` succeeds
- `mcp__XcodeBuildMCP__build_macos` succeeds
- `mcp__XcodeBuildMCP__test_macos` succeeds (40/40 tests pass)
- All 107 Swift source files discovered by folder-based scanning
- Code signing (Automatic + Developer ID) working
- Test target with correct team ID and generated Info.plist

### XcodeBuildMCP Note
XcodeBuildMCP does not have built-in xcodegen support. It works with existing xcodeproj files.
Must run `xcodegen generate` before using XcodeBuildMCP build/test tools after file changes.
