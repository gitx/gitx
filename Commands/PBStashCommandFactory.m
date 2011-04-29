//
//  PBStashCommandFactory.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBStashCommandFactory.h"
#import "PBCommand.h"
#import "PBCommandWithParameter.h"

// model
#import "PBGitStash.h"
#import "PBGitRef.h"

@interface PBStashCommandFactory()
+ (NSArray *) commandsForStash:(PBGitStash *) stash repository:(PBGitRepository *) repository;
+ (NSArray *) commandsForRef:(PBGitRef *) ref repository:(PBGitRepository *) repository;
@end


@implementation PBStashCommandFactory

+ (NSArray *) commandsForObject:(id<PBPresentable>) object repository:(PBGitRepository *) repository {
	NSArray *cmds = nil;
	if ([object isKindOfClass:[PBGitStash class]]) {
		cmds = [PBStashCommandFactory commandsForStash:(id)object repository:repository];
	} else if ([object isKindOfClass:[PBGitRef class]]) {
		cmds = [PBStashCommandFactory commandsForRef:(id)object repository:repository];
	}

	
	return cmds;
}

+ (NSArray *) commandsForRef:(PBGitRef *) ref repository:(PBGitRepository *) repository {
	NSMutableArray *commands = [[NSMutableArray alloc] init];
	
	PBGitRef *headRef = [[repository headRef] ref];
	BOOL isHead = [ref isEqualToRef:headRef];
	
	if (isHead) {
		NSArray *args = [NSArray arrayWithObject:@"stash"];
		PBCommand *command = [[PBCommand alloc] initWithDisplayName:@"Stash local changes..." parameters:args repository:repository];
		command.commandTitle = command.displayName;
		command.commandDescription = @"Stashing local changes";
		
		PBCommandWithParameter *cmd = [[PBCommandWithParameter alloc] initWithCommand:command parameterName:@"save" parameterDisplayName:@"Stash message (optional)"];
		[command release];
		[commands addObject:cmd];
		[cmd release];
		
		command = [[PBCommand alloc] initWithDisplayName:@"Clear stashes" parameters:[NSArray arrayWithObjects:@"stash", @"clear", nil] repository:repository];
		command.commandTitle = command.displayName;
		command.commandDescription = @"Clearing stashes";
		[commands addObject:command];
		[command release];
	}
	
	return [commands autorelease];
}

+ (NSArray *) commandsForStash:(PBGitStash *) stash repository:(PBGitRepository *) repository {
	NSMutableArray *commands = [[NSMutableArray alloc] init];
	
	NSArray *args = [NSArray arrayWithObjects:@"stash", @"apply", [stash name], nil];
	PBCommand *command = [[PBCommand alloc] initWithDisplayName:@"Apply" parameters:args repository:repository];
	command.commandTitle = command.displayName;
	command.commandDescription = [NSString stringWithFormat:@"Applying stash: '%@'", stash];
	[commands addObject:command];
	
	args = [NSArray arrayWithObjects:@"stash", @"pop", [stash name], nil];
	command = [[PBCommand alloc] initWithDisplayName:@"Pop" parameters:args repository:repository];
	command.commandTitle = command.displayName;
	command.commandDescription = [NSString stringWithFormat:@"Poping stash: '%@'", stash];
	[commands addObject:command];
	
	args = [NSArray arrayWithObjects:@"stash", @"drop", [stash name], nil];
	command = [[PBCommand alloc] initWithDisplayName:@"Drop" parameters:args repository:repository];
	command.commandTitle = command.displayName;
	command.commandDescription = [NSString stringWithFormat:@"Dropping stash: '%@'", stash];
	[commands addObject:command];
	
	return [commands autorelease];
}

@end
