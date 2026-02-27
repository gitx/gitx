//
//  GitX-Bridging-Header.h
//  GitX
//
//  Exposes Objective-C headers to Swift.
//
//  RULE: only add a header here when a Swift file actually needs to reference
//  the type/symbol.  Do NOT bulk-import everything — it breaks archive builds.
//  External/ headers are imported via framework imports only (no bare filenames).
//

// ── System ───────────────────────────────────────────────────────────────────
#import <Cocoa/Cocoa.h>

// ── External frameworks (framework imports only — no bare filenames) ──────────
#import <ObjectiveGit/ObjectiveGit.h>

// ── Converted files: headers kept so ObjC callers continue to compile ────────
// NSAppearance+PBDarkMode.swift owns the implementations; .m only defines the constant.
#import "NSAppearance+PBDarkMode.h"
// NSColor+RGB.swift owns the implementation.
#import "NSColor+RGB.h"
// NSSplitView+GitX.swift owns the implementation.
#import "NSSplitView+GitX.h"
// GitXRelativeDateFormatter.swift owns the implementation.
#import "GitXRelativeDateFormatter.h"

// ── Add further headers below only when a Swift source file needs them ────────
