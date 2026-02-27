//
//  NSColorRGBTests.swift
//  GitXTests
//
//  Tests for NSColor+RGB (converted from ObjC).
//

import XCTest
@testable import GitX

final class NSColorRGBTests: XCTestCase {

    func testBlack() {
        let color = NSColor.color(r: 0, g: 0, b: 0)
        assertComponents(color, r: 0, g: 0, b: 0, a: 1)
    }

    func testWhite() {
        let color = NSColor.color(r: 255, g: 255, b: 255)
        assertComponents(color, r: 1, g: 1, b: 1, a: 1)
    }

    func testPureRed() {
        let color = NSColor.color(r: 255, g: 0, b: 0)
        assertComponents(color, r: 1, g: 0, b: 0, a: 1)
    }

    func testMidGray() {
        let color = NSColor.color(r: 128, g: 128, b: 128)
        let expected = CGFloat(128) / 255.0
        assertComponents(color, r: expected, g: expected, b: expected, a: 1)
    }

    func testArbitraryColor() {
        let color = NSColor.color(r: 64, g: 128, b: 192)
        assertComponents(color,
                         r: CGFloat(64)  / 255.0,
                         g: CGFloat(128) / 255.0,
                         b: CGFloat(192) / 255.0,
                         a: 1.0)
    }

    func testAlphaIsAlwaysOne() {
        let color = NSColor.color(r: 10, g: 20, b: 30)
        var alpha: CGFloat = 0
        color.getWhite(nil, alpha: &alpha)
        // Use calibrated color space for alpha check
        let calibrated = color.usingColorSpace(.genericRGB)!
        XCTAssertEqual(calibrated.alphaComponent, 1.0, accuracy: 0.001)
    }

    // MARK: - Helper

    private func assertComponents(_ color: NSColor,
                                   r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat,
                                   accuracy: CGFloat = 0.001,
                                   file: StaticString = #file, line: UInt = #line) {
        guard let c = color.usingColorSpace(.genericRGB) else {
            XCTFail("Could not convert to genericRGB", file: file, line: line)
            return
        }
        XCTAssertEqual(c.redComponent,   r, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(c.greenComponent, g, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(c.blueComponent,  b, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(c.alphaComponent, a, accuracy: accuracy, file: file, line: line)
    }
}

