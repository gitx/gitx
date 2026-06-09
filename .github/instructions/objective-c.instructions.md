---
applyTo: "**/*.{h,m,mm}"
---

# Objective-C Coding Instructions

## Class Naming
- Prefix all project classes with `PB` (e.g., `PBGitRepository`, `PBGitCommit`)
- Controllers end in `Controller`, views end in `View`, sheets end in `Sheet`

## Headers
- Always use `NS_ASSUME_NONNULL_BEGIN` / `NS_ASSUME_NONNULL_END` in headers
- Annotate nullable properties/parameters explicitly with `nullable`
- Keep `@interface` lean — put private declarations in a class extension in the `.m` file

## Patterns
- Follow the AppKit MVC pattern: model in `Classes/git/`, views in `Classes/Views/`, controllers in `Classes/Controllers/`
- Use `NSNotificationCenter` for cross-component communication where delegates are not practical
- Prefer `dispatch_async(dispatch_get_main_queue(), ^{ … })` for UI updates from background threads

## Formatting
- Follow `.clang-format` at the repo root — run `clang-format` before committing
- Use 4-space indentation (matching existing code)
