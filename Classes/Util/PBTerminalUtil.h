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

@end
