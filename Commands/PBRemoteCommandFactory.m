//
//  PBRemoteCommandFactory.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-07.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBRemoteCommandFactory.h"
#import "PBOpenDocumentCommand.h"
#import "PBGitSubmodule.h"
#import "PBRevealWithFinderCommand.h"


@implementation PBRemoteCommandFactory

+ (NSArray *) commandsForSubmodule:(PBGitSubmodule *) submodule inRepository:(PBGitRepository *) repository {
	NSMutableArray *commands = [[NSMutableArray alloc] init];
	
	NSString *repoPath = [repository workingDirectory];
	NSString *path = [repoPath stringByAppendingPathComponent:[submodule path]];
	NSString *submodulePath = [submodule path];
	
	if ([submodule submoduleState] == PBGitSubmoduleStateNotInitialized) {
		NSArray *params = [NSArray arrayWithObjects:@"submodule", @"init", submodulePath, nil];
		PBCommand *initCmd = [[PBCommand alloc] initWithDisplayName:@"Init" parameters:params repository:repository];
		initCmd.commandTitle = initCmd.displayName;
		initCmd.commandDescription = [NSString stringWithFormat:@"Initializing submodule %@", submodulePath];
		[commands addObject:initCmd];
	}
	
	// update
	NSArray *params = [NSArray arrayWithObjects:@"submodule", @"update", submodulePath, nil];
	PBCommand *updateCmd = [[PBCommand alloc] initWithDisplayName:@"Update" parameters:params repository:repository];
	updateCmd.commandTitle = updateCmd.displayName;
 	updateCmd.commandDescription = [NSString stringWithFormat:@"Updating submodule %@", submodulePath];
	[commands addObject:updateCmd];
	
	if ([[submodule submodules] count] > 0) {
		// update recursively
		NSArray *recursiveUpdate = [NSArray arrayWithObjects:@"submodule", @"update", @"--recursive", submodulePath, nil];
		PBCommand *updateRecursively = [[PBCommand alloc] initWithDisplayName:@"Update recursively" parameters:recursiveUpdate repository:repository];
		updateRecursively.commandTitle = updateRecursively.displayName;
		updateRecursively.commandDescription = [NSString stringWithFormat:@"Updating submodule %@ (recursively)", submodulePath];
		[commands addObject:updateRecursively];
	}
	
	if ([submodule submoduleState] != PBGitSubmoduleStateNotInitialized) {
		// open
		PBOpenDocumentCommand *command = [[PBOpenDocumentCommand alloc] initWithDocumentAbsolutePath:path];
		command.commandTitle = command.displayName;
		command.commandDescription = @"Opening document";
		[commands addObject:command];
		
		[commands addObject:[[PBRevealWithFinderCommand alloc] initWithDocumentAbsolutePath:path]];
	}
	
	return commands;
}

+ (NSArray *) commandsForObject:(id<PBPresentable>) object repository:(PBGitRepository *) repository {
	if ([object isKindOfClass:[PBGitSubmodule class]]) {
		return [PBRemoteCommandFactory commandsForSubmodule:(id)object inRepository:repository];
	}
	return nil;
}

@end
