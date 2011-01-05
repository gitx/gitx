//
//  PBStashCommandFactory.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBStashCommandFactory.h"
#import "PBStashCommand.h"

// model
#import "PBGitStash.h"

@implementation PBStashCommandFactory

+ (NSArray *) commandsForObject:(NSObject *) object repository:(PBGitRepository *) repository {
	if (![object isKindOfClass:[PBGitStash class]]) {
		return nil;
	}
	PBGitStash *stash = (PBGitStash *) object;
	NSMutableArray *commands = [[NSMutableArray alloc] init];
	
	NSArray *args = [NSArray arrayWithObjects:@"apply", [stash name], nil];
	PBStashCommand *command = [[PBStashCommand alloc] initWithDisplayName:@"Apply" arguments:args repository:repository];
	command.commandTitle = command.displayName;
	command.commandDescription = [NSString stringWithFormat:@"Applying stash: '%@'", stash];
	[commands addObject:command];
	
	args = [NSArray arrayWithObjects:@"pop", [stash name], nil];
	command = [[PBStashCommand alloc] initWithDisplayName:@"Pop" arguments:args repository:repository];
	command.commandTitle = command.displayName;
	command.commandDescription = [NSString stringWithFormat:@"Poping stash: '%@'", stash];
	[commands addObject:command];
	
	args = [NSArray arrayWithObjects:@"drop", [stash name], nil];
	command = [[PBStashCommand alloc] initWithDisplayName:@"Drop" arguments:args repository:repository];
	command.commandTitle = command.displayName;
	command.commandDescription = [NSString stringWithFormat:@"Dropping stash: '%@'", stash];
	[commands addObject:command];
	
	
	return [commands autorelease];
}

@end
