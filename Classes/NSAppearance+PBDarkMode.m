//
//  NSAppearance+PBDarkMode.m
//  GitX
//
//  Only the global constant definition remains here — the category
//  implementations have been moved to NSAppearance+PBDarkMode.swift.
//

#import "NSAppearance+PBDarkMode.h"

// This definition satisfies the `extern NSString *const` declaration in the
// header for all Objective-C callers.  The Swift side imports the same value
// as a plain Swift String via the bridging header.
NSString *const PBEffectiveAppearanceChanged = @"PBEffectiveAppearanceChanged";
