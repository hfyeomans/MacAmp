## Status
- Research complete; identified that `MacAmpApp` recreated the `PlaybackCoordinator` every render.
- Implementation complete: `MacAmpApp` now stores a persistent coordinator wired to the existing audio and stream players.
- Pending verification; unable to run UI in this context.

## Next Steps
1. Manually launch the app (outside this session) and confirm the main window now shows the active track title for local files.
2. Exercise both local and streaming playback to ensure coordinator state updates remain correct.
