# State: Milkdrop Window Precision Fixes

- Titlebar/bottom sprites updated to use `.at(x:y:)` with integer offsets; drag handle now relies on top-leading alignment (no half-point `.position`).
- Need user/QA verification in app since we cannot render UI previews here.
