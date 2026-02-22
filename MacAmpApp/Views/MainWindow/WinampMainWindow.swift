import SwiftUI
import AppKit

/// Pixel-perfect recreation of Winamp's main window using absolute positioning.
/// Root composition view — delegates to child layer structs for recomposition boundaries.
struct WinampMainWindow: View {
    @Environment(SkinManager.self) private var skinManager
    @Environment(AudioPlayer.self) private var audioPlayer
    @Environment(DockingController.self) private var dockingController
    @Environment(AppSettings.self) private var settings
    @Environment(PlaybackCoordinator.self) private var playbackCoordinator
    @Environment(WindowFocusState.self) private var windowFocusState

    @State private var interactionState = WinampMainWindowInteractionState()
    @State private var optionsPresenter = MainWindowOptionsMenuPresenter()

    let pauseBlinkTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var isWindowActive: Bool {
        windowFocusState.isMainKey
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            SimpleSpriteImage("MAIN_WINDOW_BACKGROUND",
                            width: WinampSizes.main.width,
                            height: WinampSizes.main.height)

            WinampTitlebarDragHandle(windowKind: .main, size: CGSize(width: 275, height: 14)) {
                SimpleSpriteImage(isWindowActive ? "MAIN_TITLE_BAR_SELECTED" : "MAIN_TITLE_BAR",
                                width: 275,
                                height: 14)
            }
            .at(CGPoint(x: 0, y: 0))

            if !settings.isMainWindowShaded {
                MainWindowFullLayer(
                    interactionState: interactionState,
                    optionsPresenter: optionsPresenter,
                    openFileDialog: openFileDialog
                )
            } else {
                MainWindowShadeLayer(interactionState: interactionState)
            }
        }
        .frame(
            width: WinampSizes.main.width,
            height: settings.isMainWindowShaded ? WinampSizes.mainShade.height : WinampSizes.main.height,
            alignment: .topLeading
        )
        .scaleEffect(
            settings.isDoubleSizeMode ? 2.0 : 1.0,
            anchor: .topLeading
        )
        .frame(
            width: settings.isDoubleSizeMode ? WinampSizes.main.width * 2 : WinampSizes.main.width,
            height: settings.isMainWindowShaded
                ? (settings.isDoubleSizeMode ? WinampSizes.mainShade.height * 2 : WinampSizes.mainShade.height)
                : (settings.isDoubleSizeMode ? WinampSizes.main.height * 2 : WinampSizes.main.height),
            alignment: .topLeading
        )
        .fixedSize()
        .background(Color.black)
        .sheet(isPresented: Binding(
            get: { settings.showTrackInfoDialog },
            set: { settings.showTrackInfoDialog = $0 }
        )) {
            TrackInfoView()
        }
        .onChange(of: settings.showOptionsMenuTrigger) { _, newValue in
            if newValue {
                optionsPresenter.showOptionsMenu(
                    from: WinampMainWindowLayout.clutterButtonO,
                    settings: settings,
                    audioPlayer: audioPlayer,
                    isDoubleSizeMode: settings.isDoubleSizeMode
                )
                settings.showOptionsMenuTrigger = false
            }
        }
        .onAppear {
            interactionState.isViewVisible = true
            interactionState.displayTitleProvider = { [playbackCoordinator] in
                playbackCoordinator.displayTitle.isEmpty ? "MacAmp" : playbackCoordinator.displayTitle
            }
        }
        .onReceive(pauseBlinkTimer) { _ in
            if playbackCoordinator.isPaused {
                interactionState.pauseBlinkVisible.toggle()
            } else {
                interactionState.pauseBlinkVisible = true
            }
        }
        .onDisappear {
            interactionState.isViewVisible = false
            interactionState.cleanup()
        }
    }

    func openFileDialog() {
        PlaylistWindowActions.shared.presentAddFilesPanel(audioPlayer: audioPlayer, playbackCoordinator: playbackCoordinator)
    }
}

#Preview {
    WinampMainWindow()
        .environment(SkinManager())
        .environment(AudioPlayer())
        .environment(DockingController())
}
