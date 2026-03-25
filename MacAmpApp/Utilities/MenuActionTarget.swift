import AppKit

/// Bridges closures to NSMenuItem @objc action selectors.
/// Used by any view/presenter that builds NSMenu items with closure-based actions.
@MainActor
final class MenuActionTarget: NSObject {
    let action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @objc func execute() {
        action()
    }
}

/// Factory for creating NSMenuItems backed by MenuActionTarget closures.
@MainActor
enum MenuItemFactory {
    static func createMenuItem(
        title: String,
        isChecked: Bool = false,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: keyEquivalent)
        item.state = isChecked ? .on : .off
        item.keyEquivalentModifierMask = modifiers

        let actionTarget = MenuActionTarget(action: action)
        item.target = actionTarget
        item.action = #selector(MenuActionTarget.execute)
        item.representedObject = actionTarget

        return item
    }
}
