It sounds like you're running into the default padding that AppKit applies to menu items, which exists outside of your SwiftUI view's layout constraints. Even though you've correctly constrained your VStack to 22 pixels, the NSMenuItem that NSHostingMenu creates to host your SwiftUI view has its own standard insets, creating that "bubble" effect.

Here are a few idiomatic SwiftUI approaches to override this default padding and achieve the tight layout you're looking for.

1. Use a Custom ButtonStyle

The most robust and reusable method is to create a custom ButtonStyle that removes all padding. This gives you precise control over the button's appearance and hit area. NSHostingMenu will respect the minimal size requested by this style.

Here is a style that removes all padding and provides a subtle background highlight on press, mimicking native menu behavior:

Swift
struct TightMenuStyleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
           .padding(0) // Explicitly remove all padding around the button's content.
           .contentShape(Rectangle()) // Ensure the entire 22px area is tappable.
    }
}
You would then apply this style to each of your sprite buttons within the menu's content view. The .frame(width: 22) on the parent VStack may no longer be necessary, as the button style itself will enforce the tight layout.

Implementation:

Swift
struct MyMenuContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { /* Add action */ }) {
                Image("add_sprite") // Your 22x18 sprite
                   .interpolation(.none) // Keep pixels sharp
            }
           .buttonStyle(TightMenuStyleButton())

            Button(action: { /* Remove action */ }) {
                Image("rem_sprite")
                   .interpolation(.none)
            }
           .buttonStyle(TightMenuStyleButton())

            //... other buttons
        }
    }
}
2. Apply listRowInsets

Since NSHostingMenu renders its content in a manner similar to a SwiftUI List, you can use the .listRowInsets modifier to eliminate the padding around each item.   

Apply this modifier directly to each Button inside your VStack.

Implementation:

Swift
struct MyMenuContentView: View {
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { /* Add action */ }) {
                Image("add_sprite")
                   .interpolation(.none)
            }
           .listRowInsets(EdgeInsets()) // Remove all insets for this menu item.

            Button(action: { /* Remove action */ }) {
                Image("rem_sprite")
                   .interpolation(.none)
            }
           .listRowInsets(EdgeInsets())

            //... other buttons
        }
       .padding(0)
       .frame(width: 22) // Keep this to ensure the VStack itself doesn't expand.
    }
}
Summary and Recommendation

Both methods effectively solve the horizontal padding issue.

Start with the custom ButtonStyle. It's the most idiomatic and maintainable solution for creating custom, reusable button appearances in SwiftUI, and it perfectly addresses your need for a compact, padding-free menu item.

If you prefer a quicker, more direct modifier, .listRowInsets(EdgeInsets()) is an excellent alternative that directly targets the item's container padding.

By using one of these approaches, you are instructing the NSHostingMenu layout system to create NSMenuItems that do not add their default horizontal padding, resulting in the tight, retro-style layout you want.