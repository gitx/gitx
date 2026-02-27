//
//  NSAppearanceDarkModeTests.swift
//  GitXTests
//
//  Tests for NSAppearance+PBDarkMode (converted from ObjC).
//

import XCTest
@testable import GitX

final class NSAppearanceDarkModeTests: XCTestCase {

    // MARK: - NSAppearance.isDarkMode

    func testAquaIsNotDarkMode() {
        let appearance = NSAppearance(named: .aqua)!
        XCTAssertFalse(appearance.isDarkMode)
    }

    func testDarkAquaIsDarkMode() {
        let appearance = NSAppearance(named: .darkAqua)!
        XCTAssertTrue(appearance.isDarkMode)
    }

    func testVibrantLightIsNotDarkMode() {
        let appearance = NSAppearance(named: .vibrantLight)!
        XCTAssertFalse(appearance.isDarkMode)
    }

    func testVibrantDarkIsDarkMode() {
        let appearance = NSAppearance(named: .vibrantDark)!
        XCTAssertTrue(appearance.isDarkMode)
    }

    // MARK: - NSApplication.isDarkMode

    func testApplicationIsDarkModeMatchesEffectiveAppearance() {
        // NSApp.isDarkMode must agree with its effectiveAppearance
        let expected = NSApp.effectiveAppearance.isDarkMode
        XCTAssertEqual(NSApp.isDarkMode, expected)
    }

    // MARK: - Constant

    func testPBEffectiveAppearanceChangedValue() {
        XCTAssertEqual(PBEffectiveAppearanceChanged, "PBEffectiveAppearanceChanged")
    }
}

