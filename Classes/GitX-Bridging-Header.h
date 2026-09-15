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

// ── Converted files: headers kept so ObjC callers continue to compile ────────
// Note: these Swift twins are NOT compiled (absent from the Xcode target);
// the .m/.h implementations remain authoritative.
#import "NSAppearance+PBDarkMode.h"
#import "NSColor+RGB.h"
#import "NSSplitView+GitX.h"
#import "GitXRelativeDateFormatter.h"

// ── Add further headers below only when a Swift source file needs them ────────
// PBCommitList.swift needs these:
#import "PBMacros.h"
#import "PBCommitList.h"
#import "PBGitRevisionCell.h"
#import "PBWebHistoryController.h"
#import "PBHistorySearchController.h"
#import "PBGitHistoryController.h"
#import "PBGitCommit.h"
#import "PBGitRef.h"
