---
applyTo: "**/*.swift"
---

# Swift Coding Instructions

## Interoperability
- Swift files interop with Objective-C via `GitX-Bridging-Header.h` — add new Objective-C imports there when needed
- Expose Swift types to Objective-C with `@objc` / `@objcMembers` only when required
- Match the `PB`-prefix naming convention when subclassing or extending Objective-C `PB`-prefixed types

## Style
- Prefer `struct` over `class` for pure value types with no identity requirements
- Use Swift concurrency (`async`/`await`) for new asynchronous code; avoid mixing with `DispatchQueue` unless bridging to existing Objective-C async code
- Use `guard` for early exits instead of deeply nested `if` statements

## AppKit
- All UI work must happen on the main actor — annotate view subclasses with `@MainActor`
- Prefer `NSViewController` lifecycle methods (`viewDidLoad`, `viewWillAppear`) over manual setup
