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


@implementation PBRemoteCommandFactory

+ (NSArray *) commandsForSubmodule:(PBGitSubmodule *) submodule inRepository:(PBGitRepository *) repository {
	NSMutableArray *commands = [[NSMutableArray alloc] init];
	
	NSString *repoPath = [repository workingDirectory];
	
	NSString *path = [repoPath stringByAppendingPathComponent:[submodule path]];
	
	PBOpenDocumentCommand *command = [[PBOpenDocumentCommand alloc] initWithDocumentAbsolutePath:path];
	command.commandTitle = command.displayName;
	command.commandDescription = @"Opening document";
	[commands addObject:command];

	return commands;
}

+ (NSArray *) commandsForObject:(NSObject *) object repository:(PBGitRepository *) repository {
	if ([object isKindOfClass:[PBGitSubmodule class]]) {
		return [PBRemoteCommandFactory commandsForSubmodule:(id)object inRepository:repository];
	}
	return nil;
}

@end
