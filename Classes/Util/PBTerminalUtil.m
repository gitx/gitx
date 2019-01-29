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

@interface PBTerminalUtil () <SBApplicationDelegate>
@end

@implementation PBTerminalUtil

+ (void)runCommand:(NSString *)command inDirectory:(NSURL *)directory {
	[[self terminalHandler] runCommand:command inDirectory:directory];
}

+ (instancetype)terminalHandler {
	static dispatch_once_t onceToken;
	static PBTerminalUtil *term = nil;
	dispatch_once(&onceToken, ^{
		term = [[self alloc] init];
	});
	return term;
}

- (void)runCommand:(NSString *)command inDirectory:(NSURL *)directory {
	NSString *terminalHandler = [PBGitDefaults terminalHandler];
	BOOL ran = NO;

	if ([terminalHandler isEqualToString:@"com.googlecode.iterm2"]) {
		ran = [self runiTerm2Command:command inDirectory:directory];
	}

	// Fall back to Apple Terminal.
	if (!ran) {
		if (![terminalHandler isEqualToString:@"com.apple.Terminal"])
			NSLog(@"Unexpected terminal handler %@, using Terminal.app", terminalHandler);
		ran = [self runTerminalCommand:command inDirectory:directory];
	}

	if (!ran) {
		NSLog(@"No usable terminal handler found");
	}
}

- (nullable id)eventDidFail:(const AppleEvent *)event withError:(NSError *)error {
	NSLog(@"terminal handler error: %@", error);
	return nil;
}

- (BOOL)runTerminalCommand:(NSString *)command inDirectory:(NSURL *)directory {
	NSString *fullCommand = [NSString stringWithFormat:@"cd \"%@\"; clear; echo '# Opened by GitX'; %@", directory.path, command];

	TerminalApplication *term = [SBApplication applicationWithBundleIdentifier: @"com.apple.Terminal"];
	if (!term)
		return NO;
	term.delegate = self;

	[term doScript:fullCommand in: nil];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[term activate];
	});

	return YES;
}

- (BOOL)runiTerm2Command:(NSString *)command inDirectory:(NSURL *)directory {
	NSString *fullCommand = [NSString stringWithFormat:@"cd \"%@\"; clear; echo '# Opened by GitX'; %@", directory.path, command];

	iTerm2Application *term = [SBApplication applicationWithBundleIdentifier: @"com.googlecode.iterm2"];
	if (!term)
		return NO;
	term.delegate = self;

	iTerm2Window *win = [term createWindowWithDefaultProfileCommand:nil];
	[win.currentSession writeContentsOfFile:nil text:fullCommand newline:YES];

	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[term activate];
	});

	return YES;
}

@end
