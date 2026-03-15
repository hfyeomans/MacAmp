# Swift Patterns

## Why Swift Needs Extra Checks

Swift duplication risk often hides in:

- `Task { @MainActor in ... }`
- actor or queue crossings
- SwiftUI lifecycle hooks
- observer registration
- coordinator bypasses

These should be treated as high-priority behavioral duplication surfaces.

## Useful `ast-grep` Patterns

Examples:

```bash
sg --lang swift -p '$OBJ.$METHOD($$$ARGS)' <root>
sg --lang swift -p 'Task { @MainActor in $$$BODY }' <root>
sg --lang swift -p '.onAppear { $$$BODY }' <root>
sg --lang swift -p '.onChange(of: $$$VALUE) { $$$BODY }' <root>
sg --lang swift -p 'NotificationCenter.default.addObserver($$$ARGS)' <root>
```

Use these to answer:

- does the same stateful method run from multiple isolation contexts?
- is the same side effect attached from multiple lifecycle hooks?
- does a direct call bypass the intended coordinator?

## MacAmp-Relevant Examples

Examples of risky symbols in this repo:

- `configureFramer`
- `activateStreamBridge`
- `deactivateStreamBridge`

These are not globally special names. They matter because they control stateful ownership
and graph wiring.

If the current investigation involves split setup/teardown ownership or stale async bridge
callbacks, load [`example-macamp-bridge-ownership.md`](example-macamp-bridge-ownership.md).
