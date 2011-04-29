//
//  PBStashController.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-27.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import "PBStashController.h"
#import "PBGitRepository.h"
#import "PBCommand.h"
#import "PBCommandWithParameter.h"

static NSString * const kCommandName = @"stash";

@interface PBStashController()
@property (nonatomic, retain) NSArray *stashes;
@end



@implementation PBStashController
@synthesize stashes;

- (id) initWithRepository:(PBGitRepository *) repo {
    if ((self = [super init])){
        repository = [repo retain];
    }
    return self;
}

- (void)dealloc {
    [repository release];
    [stashes release];
    [super dealloc];
}

- (void) reload {
    NSArray *arguments = [NSArray arrayWithObjects:kCommandName, @"list", nil];
	NSString *output = [repository outputInWorkdirForArguments:arguments];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];
	
	NSMutableArray *loadedStashes = [[NSMutableArray alloc] initWithCapacity:[lines count]];
	
	for (NSString *stashLine in lines) {
		if ([stashLine length] == 0)
			continue;
		PBGitStash *stash = [[PBGitStash alloc] initWithRawStashLine:stashLine];
		[loadedStashes addObject:stash];
		[stash release];
	}
	
	self.stashes = loadedStashes;
	[loadedStashes release];
}

#pragma mark Actions

- (void) stashLocalChanges {
	NSArray *args = [NSArray arrayWithObject:kCommandName];
	PBCommand *command = [[PBCommand alloc] initWithDisplayName:@"Stash local changes..." parameters:args repository:repository];
	command.commandTitle = command.displayName;
	command.commandDescription = @"Stashing local changes";
	
	PBCommandWithParameter *cmd = [[PBCommandWithParameter alloc] initWithCommand:command parameterName:@"save" parameterDisplayName:@"Stash message (optional)"];
	[command release];
	
	[cmd invoke];
	[cmd release];
}

- (void) clearAllStashes {
	PBCommand *command = [[PBCommand alloc] initWithDisplayName:@"Clear stashes" parameters:[NSArray arrayWithObjects:kCommandName, @"clear", nil] repository:repository];
	command.commandTitle = command.displayName;
	command.commandDescription = @"Clearing stashes";
	[command invoke];
	[command release];
}

#pragma mark Menu

- (NSArray *) menu {
	NSMutableArray *array = [[NSMutableArray alloc] init];
	
	NSMenuItem *stashChanges = [[NSMenuItem alloc] initWithTitle:@"Stash local changes..." action:@selector(stashLocalChanges) keyEquivalent:@""];
	[stashChanges setTarget:self];
	NSMenuItem *clearStashes = [[NSMenuItem alloc] initWithTitle:@"Clear stashes" action:@selector(clearAllStashes) keyEquivalent:@""];
	[clearStashes setTarget:self];
	
	[array addObject:stashChanges];
	[array addObject:clearStashes];
	
	return array;
}

- (BOOL) validateMenuItem:(NSMenuItem *) item {
	SEL action = [item action];
	BOOL shouldBeEnabled = YES;
	
	if (action == @selector(stashLocalChanges)) {
		//TODO: check if we have unstaged changes
	} else if (action == @selector(clearAllStashes)) {
		shouldBeEnabled = [self.stashes count] > 0;
	}
	
	return shouldBeEnabled;
}


@end
