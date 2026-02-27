//
//  NSAppearance+PBDarkMode.swift
//  GitX
//
//  Converted from NSAppearance+PBDarkMode.m
//  Original by Etienne, 2018.
//
//  Note: NSAppearance+PBDarkMode.m is still compiled solely to provide the
//  `extern NSString *const PBEffectiveAppearanceChanged` definition for ObjC
//  callers.  The category implementations live here.
//

import AppKit

// Swift-side alias so Swift code can use the constant by name.
// The authoritative definition lives in NSAppearance+PBDarkMode.m.
let PBEffectiveAppearanceChanged: String = "PBEffectiveAppearanceChanged"

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
        // Retain the token on NSApp so it lives for the lifetime of the app.
        objc_setAssociatedObject(
            self,
            &NSApplication.appearanceObservationKey,
            token,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private static var appearanceObservationKey: UInt8 = 0
}
