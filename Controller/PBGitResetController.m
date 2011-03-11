//
//  PBGitResetController.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-27.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBGitResetController.h"
#import "PBGitRepository.h"
#import "PBCommand.h"

static NSString * const kCommandKey = @"command";

@implementation PBGitResetController

- (id) initWithRepository:(PBGitRepository *) repo {
	if ((self = [super init])){
        repository = [repo retain];
    }
    return self;
}

- (void) resetHardToHead {
	NSAlert *alert = [NSAlert alertWithMessageText:@"Reseting working copy and index"
									 defaultButton:@"Cancel"
								   alternateButton:nil
									   otherButton:@"Reset"
						 informativeTextWithFormat:@"Are you sure you want to reset your working copy and index? All changes to them will be gone!"];
	
	NSArray *arguments = [NSArray arrayWithObjects:@"reset", @"--hard", @"HEAD", nil];
	PBCommand *cmd = [[PBCommand alloc] initWithDisplayName:@"Reset hard to HEAD" parameters:arguments repository:repository];
	cmd.commandTitle = cmd.displayName;
	cmd.commandDescription = @"Reseting head";
	
	NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:cmd forKey:kCommandKey];
	
	[alert beginSheetModalForWindow:[repository.windowController window]
					  modalDelegate:self
					 didEndSelector:@selector(confirmResetSheetDidEnd:returnCode:contextInfo:)
						contextInfo:info];
}

- (void) reset {
	//TODO missing implementation
}

- (NSArray *) menuItems {
	NSMenuItem *resetHeadHardly = [[NSMenuItem alloc] initWithTitle:@"Reset hard to HEAD" action:@selector(resetHardToHead) keyEquivalent:@""];
	[resetHeadHardly setTarget:self];
	
	NSMenuItem *reset = [[NSMenuItem alloc] initWithTitle:@"Reset..." action:@selector(reset) keyEquivalent:@""];
	[reset setTarget:self];
	
	return [NSArray arrayWithObjects:resetHeadHardly, reset, nil];
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem {
	BOOL shouldBeEnabled = YES;
	SEL action = [menuItem action];
	if (action == @selector(reset)) {
		shouldBeEnabled = NO;
		//TODO missing implementation
	}
	return shouldBeEnabled;
}

- (void) dealloc {
	[repository release];
	[super dealloc];
}

#pragma mark -
#pragma mark Confirm Window

- (void) confirmResetSheetDidEnd:(NSAlert *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [[sheet window] orderOut:nil];
	
	if (returnCode != NSAlertDefaultReturn) {
		PBCommand *cmd = [(NSDictionary *)contextInfo objectForKey:kCommandKey];
		[cmd invoke];
	}
}


@end
