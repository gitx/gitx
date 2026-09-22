//
//  PBTerminalUtil.h
//  GitX
//
//  Created by Sven on 07.08.16.
//
//

#import <Foundation/Foundation.h>

extern NSString *const PBTerminalHandlerTerminal;
extern NSString *const PBTerminalHandleriTerm2;

/*
 * Where GitX should put the session it is about to open.
 */
typedef NS_ENUM(NSInteger, PBTerminalSessionPlan) {
	/* Take the window the handler opens for itself as it launches. */
	PBTerminalSessionPlanLaunchedWindow,
	PBTerminalSessionPlanNewTab,
	PBTerminalSessionPlanNewWindow,
};

@interface PBTerminalUtil : NSObject

/*
 * Runs the given command in the terminal application the user has chosen,
 * at the given directory.
 */
+ (void)runCommand:(NSString *)command inDirectory:(NSURL *)directory;

/*
 * Bundle identifiers of the terminal applications GitX can drive, in the
 * order they should be offered.
 */
+ (NSArray<NSString *> *)supportedHandlers;

/*
 * The name to show for a supported handler, or nil for anything else.
 */
+ (NSString *)nameForHandler:(NSString *)bundleIdentifier;

/*
 * Whether the handler is installed on this machine.
 */
+ (BOOL)isHandlerInstalled:(NSString *)bundleIdentifier;

/*
 * The handler to use for a stored preference, falling back to Terminal for
 * anything GitX cannot drive.
 */
+ (NSString *)handlerForPreference:(NSString *)bundleIdentifier;

/*
 * Whether GitX can open a new tab in a handler's existing window, rather than
 * always opening a new window.
 */
+ (BOOL)handlerSupportsTabs:(NSString *)bundleIdentifier;

/*
 * The shell line GitX writes into a freshly opened session to run a command
 * at a directory.
 */
+ (NSString *)shellLineForCommand:(NSString *)command inDirectory:(NSURL *)directory;

/*
 * Where to put the session, given what the handler is doing right now and
 * whether the user asked for a tab.
 */
+ (PBTerminalSessionPlan)sessionPlanWhenRunning:(BOOL)running hasOpenWindow:(BOOL)hasOpenWindow openAsTab:(BOOL)openAsTab;

@end
