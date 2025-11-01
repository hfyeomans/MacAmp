Modernized Implementation Plan: Doublesize Mode (Swift 6 / macOS 15+)

This revised plan is structured in five phases, incorporating modern Swift 6 features like the @Observable macro and new SwiftUI APIs for enhanced window control. The architecture remains centered on a clean separation of concerns, with a reactive state model driving both the UI and the underlying window behavior.

Phase 1: Centralized State Management with @Observable

The core of the feature is a reactive state model that serves as the single source of truth. Swift 6's @Observable macro simplifies this process, eliminating the need for @Published property wrappers and providing more performant, field-by-field observation.

Objective: Create a modern, efficient, and observable state object to manage the application's UI state.

Key Tasks:

Define the Observable Model: Create a class using the @Observable macro. This class will hold all shared UI state.

Swift
@Observable
class UIStateModel {
    var isDoublesize: Bool = false
    weak var window: NSWindow? // Reference to the AppKit window
}
Dependency Injection: Instantiate UIStateModel at the root of the application and inject it into the SwiftUI environment. This makes the state accessible to any view that needs it.

Swift
@main
struct WinampCloneApp: App {
    @State private var uiState = UIStateModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
               .environment(uiState)
        }
    }
}
Phase 2: Skin-Driven UI with a Custom ButtonStyle

To ensure the button's appearance is dictated entirely by the skin files and behaves like a native control, we will create a custom ButtonStyle. This is a more idiomatic and reusable approach in SwiftUI than a simple view with a tap gesture.

Objective: Render the 'D' button using images from the loaded skin and create a reusable style that reacts to its on/off state.

Key Tasks:

Skin Engine Service: Define a service (e.g., @Observable class SkinEngine) responsible for loading and slicing the skin's bitmap assets, such as cbuttons.bmp and titlebar.bmp. This service will provide functions to retrieve the specific image for a button's "on" and "off" states.

Create a Custom ButtonStyle:

Define a new struct, SkinToggleButton, that conforms to the ButtonStyle protocol.

The style will take the "on" and "off" image names as parameters.

Inside its makeBody method, it will check the button's configuration (e.g., configuration.isPressed) and the bound state to display the correct image slice from the SkinEngine.

Implement the Button View:

In the main UI, create a Toggle or Button that binds directly to the isDoublesize property in the UIStateModel.

Apply the custom SkinToggleButton style to it. This encapsulates the visual logic and interaction behavior cleanly.

Swift
// In your main view
@Environment(UIStateModel.self) private var uiState

Toggle("", isOn: $uiState.isDoublesize)
   .toggleStyle(.button) // Render as a button
   .buttonStyle(SkinToggleStyle(onImage: "d.on", offImage: "d.off"))
Phase 3: AppKit Bridge for Imperative Window Control

Directly manipulating the NSWindow frame remains an AppKit task. The bridge ensures this imperative code is executed reactively when the SwiftUI state changes.

Objective: Establish a clean, reactive connection between the UIStateModel and the AppKit NSWindow object.

Key Tasks:

Window Accessor: Use a lightweight NSViewRepresentable (WindowAccessor) to get a reference to the hosting NSWindow once and store it in the UIStateModel. This is done once when the view appears.

Reactive Task Modifier: Use the .task(id:priority:_:) modifier to observe the isDoublesize state. This modern concurrency feature provides a structured way to run asynchronous code in response to state changes, making it the ideal place to house the AppKit interaction logic.

Swift
// In your main view
.task(id: uiState.isDoublesize) { // This block re-runs whenever isDoublesize changes. resizeWindow(doublesize: uiState.isDoublesize) } ```

Phase 4: Modern Animated Resizing with .windowResizeAnchor

This phase focuses on executing the resize animation smoothly and correctly. By leveraging new APIs in macOS 15, we can achieve a more precise and visually stable animation that honors the original Winamp behavior.

Objective: Programmatically resize the window with a smooth animation anchored to the top-left corner, ensuring all SwiftUI content scales correctly.

Key Tasks:

Set Resize Anchor: Apply the .windowResizeAnchor(.topLeading) modifier to the main content view. This new macOS 15 API ensures that when the window's frame is animated, it expands and contracts from the top-left corner, preventing the window from "jumping" on screen.   
Unified Animation Logic (within the .task modifier):

Retrieve the NSWindow from the UIStateModel.

Calculate the target frame based on the isDoublesize state (100% or 200%).

Use NSAnimationContext.runAnimationGroup to wrap the AppKit call. This allows SwiftUI's animation timing curves to be applied to AppKit animations, creating a single, unified animation system across the entire app.   
Inside the animation group, call window.setFrame(newFrame, display: true). The animation context handles the smooth transition.   

Scalable SwiftUI Content:

Build the UI with resizable components. The main skin background must be an Image with the .resizable() modifier.

Use layout containers like VStack and HStack to allow controls to reflow naturally. For custom-drawn elements like a spectrum analyzer, use GeometryReader to ensure they render relative to their container's size.   
Phase 5: Native Keyboard Shortcut Integration

The Ctrl+D shortcut is a core part of the feature's identity. SwiftUI provides a direct, declarative way to implement this.

Objective: Implement the Ctrl+D keyboard shortcut to toggle the doublesize state.

Key Tasks:

Declarative Shortcut: Attach the .keyboardShortcut("d", modifiers:.control) modifier to the Toggle view.

Unified State Change: Because the Toggle is already bound to $uiState.isDoublesize, the keyboard shortcut will automatically update the central state model. This triggers the same reactive chain of events as a mouse click, ensuring both input methods are perfectly synchronized with no extra logic required.