//
//  NSColor+RGB.swift
//  GitX
//
//  Converted from NSColor+RGB.m
//  Original by Rowan James.
//

import AppKit

extension NSColor {

    /// Creates a calibrated NSColor from 8-bit RGB components (0–255).
    @objc(colorWithR:G:B:)
    static func color(r: UInt8, g: UInt8, b: UInt8) -> NSColor {
        let max: CGFloat = 255.0
        return NSColor(calibratedRed: CGFloat(r) / max,
                       green:         CGFloat(g) / max,
                       blue:          CGFloat(b) / max,
                       alpha:         1.0)
    }
}

