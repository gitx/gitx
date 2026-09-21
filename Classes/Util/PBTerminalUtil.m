//
//  PBTerminalUtil.m
//  GitX
//
//  Created by Sven on 07.08.16.
//

#import "PBTerminalUtil.h"
#import "Terminal.h"
#import "iTerm2GeneratedScriptingBridge.h"
#import "PBGitDefaults.h"

#import <AppKit/AppKit.h>

NSString *const PBTerminalHandlerTerminal = @"com.apple.Terminal";
NSString *const PBTerminalHandleriTerm2 = @"com.googlecode.iterm2";

static const NSTimeInterval PBTerminalLaunchedWindowTimeout = 5.0;
static const NSTimeInterval PBTerminalLaunchedWindowPollInterval = 0.05;

@interface PBTerminalUtil () <SBApplicationDelegate>
@end

@implementation PBTerminalUtil

+ (void)runCommand:(NSString *)command inDirectory:(NSURL *)directory
{
	[[self terminalHandler] runCommand:command inDirectory:directory];
}

+ (instancetype)terminalHandler
{
	static dispatch_once_t onceToken;
	static PBTerminalUtil *term = nil;
	dispatch_once(&onceToken, ^{
		term = [[self alloc] init];
	});
	return term;
}

+ (NSArray<NSString *> *)supportedHandlers
{
	return @[ PBTerminalHandlerTerminal, PBTerminalHandleriTerm2 ];
}

+ (NSString *)nameForHandler:(NSString *)bundleIdentifier
{
	if ([bundleIdentifier isEqualToString:PBTerminalHandlerTerminal]) {
		return @"Terminal";
	}
	if ([bundleIdentifier isEqualToString:PBTerminalHandleriTerm2]) {
		return @"iTerm2";
	}
	return nil;
}

+ (BOOL)isHandlerInstalled:(NSString *)bundleIdentifier
{
	if (!bundleIdentifier) {
		return NO;
	}
	return [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:bundleIdentifier] != nil;
}

+ (NSString *)handlerForPreference:(NSString *)bundleIdentifier
{
	if (bundleIdentifier.length == 0) {
		return PBTerminalHandlerTerminal;
	}

	if ([[self supportedHandlers] containsObject:bundleIdentifier]) {
		return bundleIdentifier;
	}

	NSLog(@"Unexpected terminal handler %@, using Terminal", bundleIdentifier);

	return PBTerminalHandlerTerminal;
}

+ (BOOL)handlerSupportsTabs:(NSString *)bundleIdentifier
{
	return [bundleIdentifier isEqualToString:PBTerminalHandleriTerm2];
}

+ (NSString *)shellLineForCommand:(NSString *)command inDirectory:(NSURL *)directory
{
	return [NSString stringWithFormat:@"cd \"%@\"; tput clear; echo '# Opened by GitX'; %@", directory.path, command];
}

+ (PBTerminalSessionPlan)sessionPlanWhenRunning:(BOOL)running hasOpenWindow:(BOOL)hasOpenWindow openAsTab:(BOOL)openAsTab
{
	if (!running) {
		return PBTerminalSessionPlanLaunchedWindow;
	}

	if (openAsTab && hasOpenWindow) {
		return PBTerminalSessionPlanNewTab;
	}

	return PBTerminalSessionPlanNewWindow;
}

- (void)runCommand:(NSString *)command inDirectory:(NSURL *)directory
{
	NSString *terminalHandler = [PBTerminalUtil handlerForPreference:[PBGitDefaults terminalHandler]];
	BOOL ran = NO;

	if ([terminalHandler isEqualToString:PBTerminalHandleriTerm2]) {
		ran = [self runiTerm2Command:command inDirectory:directory];
	}

	// Fall back to Apple Terminal.
	if (!ran) {
		ran = [self runTerminalCommand:command inDirectory:directory];
	}

	if (!ran) {
		NSLog(@"No usable terminal handler found");
	}
}

- (nullable id)eventDidFail:(const AppleEvent *)event withError:(NSError *)error
{
	NSLog(@"terminal handler error: %@", error);
	return nil;
}

- (BOOL)runTerminalCommand:(NSString *)command inDirectory:(NSURL *)directory
{
	NSString *fullCommand = [PBTerminalUtil shellLineForCommand:command inDirectory:directory];

	TerminalApplication *term = [SBApplication applicationWithBundleIdentifier:PBTerminalHandlerTerminal];
	if (!term)
		return NO;
	term.delegate = self;

	[term doScript:fullCommand in:nil];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[term activate];
	});

	return YES;
}

- (BOOL)runiTerm2Command:(NSString *)command inDirectory:(NSURL *)directory
{
	NSString *fullCommand = [PBTerminalUtil shellLineForCommand:command inDirectory:directory];

	iTerm2Application *term = [SBApplication applicationWithBundleIdentifier:PBTerminalHandleriTerm2];
	if (!term)
		return NO;
	term.delegate = self;

	iTerm2Session *session = [self iTerm2SessionForApplication:term];
	if (!session)
		return NO;

	[session writeContentsOfFile:nil text:fullCommand newline:YES];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[term activate];
	});

	return YES;
}

- (iTerm2Session *)iTerm2SessionForApplication:(iTerm2Application *)term
{
	BOOL running = [term isRunning];
	BOOL hasOpenWindow = running && [term.currentWindow exists];
	PBTerminalSessionPlan plan = [PBTerminalUtil sessionPlanWhenRunning:running
															hasOpenWindow:hasOpenWindow
																openAsTab:[PBGitDefaults terminalOpenAsTab]];

	switch (plan) {
		case PBTerminalSessionPlanLaunchedWindow:
			return [self iTerm2SessionByLaunching:term];
		case PBTerminalSessionPlanNewTab:
			return [term.currentWindow createTabWithDefaultProfileCommand:nil].currentSession;
		case PBTerminalSessionPlanNewWindow:
			return [term createWindowWithDefaultProfileCommand:nil].currentSession;
	}
}

- (iTerm2Session *)iTerm2SessionByLaunching:(iTerm2Application *)term
{
	[term activate];

	NSDate *giveUp = [NSDate dateWithTimeIntervalSinceNow:PBTerminalLaunchedWindowTimeout];
	while ([giveUp timeIntervalSinceNow] > 0) {
		iTerm2Window *win = term.currentWindow;
		if ([win exists]) {
			return win.currentSession;
		}

		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
								 beforeDate:[NSDate dateWithTimeIntervalSinceNow:PBTerminalLaunchedWindowPollInterval]];
	}

	NSLog(@"iTerm2 opened no window of its own within %g seconds; asking for one", PBTerminalLaunchedWindowTimeout);

	return [term createWindowWithDefaultProfileCommand:nil].currentSession;
}

@end
