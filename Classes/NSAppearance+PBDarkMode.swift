//
//  NSAppearance+PBDarkMode.swift
//  GitX
//
//  Converted from NSAppearance+PBDarkMode.m
//  Original by Etienne, 2018.
//

import AppKit

/// Posted whenever the effective appearance of NSApplication changes.
@objc let PBEffectiveAppearanceChanged = "PBEffectiveAppearanceChanged"

// MARK: - NSAppearance

extension NSAppearance {
    /// Returns `true` when this appearance resolves to Dark Aqua.
    @objc var isDarkMode: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

// MARK: - NSApplication

extension NSApplication {
    /// Returns `true` when the application's effective appearance is Dark Aqua.
    @objc var isDarkMode: Bool {
        effectiveAppearance.isDarkMode
    }

    /// Registers `observer` for KVO on `effectiveAppearance` and re-posts
    /// `PBEffectiveAppearanceChanged` whenever it changes.
    /// The observation token is retained on `self` (i.e. NSApp) so it lives
    /// for the lifetime of the application — matching the original behaviour.
    @objc func registerObserverForAppearanceChanges(_ observer: Any) {
        let token = NSApp.observe(\.effectiveAppearance) { _, _ in
            NotificationCenter.default.post(
                name: Notification.Name(PBEffectiveAppearanceChanged),
                object: observer
            )
        }
        // Retain the token on NSApp via the ObjC associated-objects API so it
        // is never deallocated (same intentional "leak" as the original comment).
        objc_setAssociatedObject(
            self,
            &NSApplication.appearanceObservationKey,
            token,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private static var appearanceObservationKey: UInt8 = 0
}
