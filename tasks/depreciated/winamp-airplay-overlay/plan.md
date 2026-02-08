# Plan: Winamp Logo AirPlay Overlay Pattern

1. Summarize AVRoutePickerView constraints from research: must be interacted with directly; no programmatic presentation.
2. Recommend Option A (embed picker view directly over logo) and justify against other options.
3. Provide reusable `NSViewRepresentable` wrapper (`AirPlayRoutePicker`) with configuration knobs (size, appearance, delegate hooks).
4. Show integration snippet inside `WinampMainWindow` using `.overlay`/`.at` pattern that aligns the picker over the Winamp logo coordinates (approx 253×91 from Webamp baseline, scaled for SwiftUI pixel grid).
5. Document frame sizing considerations, hitbox expansion, and accessibility label guidance.
6. Answer each of the user's specific questions explicitly.
