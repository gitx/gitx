//
//  PBTerminalUtil.m
//  GitX
//
//  Created by Sven on 07.08.16.
//

#import "PBTerminalUtil.h"
#import "Terminal.h"
#import "iTerm2GeneratedScriptingBridge.h"

@implementation PBTerminalUtil

+ (NSString *) terminalCommand:(NSString *)command inDirectory:(NSURL *)directory {
	return [NSString stringWithFormat:@"cd \"%@\"; clear; echo '# Opened by GitX'; %@",
			directory.path, command];
}

+ (NSString *) iTerm2Command:(NSString *)command inDirectory:(NSURL *)directory {
	return [NSString stringWithFormat:@"/usr/bin/login -f %@ /bin/sh -c 'cd \"%@\"; clear; echo \"# Opened by GitX\"; %@; ${SHELL} -l",
			NSUserName(), directory.path, command];
}
+ (void) runCommand:(NSString *)command inDirectory:(NSURL *)directory {
	NSLog(@"Running command: %@ in directory %@", command, directory.path);
	
	// Prefer iTerm2. If they have it installed they probably want to use that.
	iTerm2Application *iTerm2 = [SBApplication applicationWithBundleIdentifier: @"com.googlecode.iterm2"];
	if (iTerm2 != nil) {
		NSString * fullCommand = [self iTerm2Command:command inDirectory:directory];
		[iTerm2 createWindowWithDefaultProfileCommand:fullCommand];
	} else {
		// Fall back to Apple Terminal.
		TerminalApplication *term = [SBApplication applicationWithBundleIdentifier: @"com.apple.Terminal"];
		NSString * fullCommand = [self terminalCommand:command inDirectory:directory];
		[term doScript:fullCommand in: nil];
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[term activate];
		});
	}
}

@end
