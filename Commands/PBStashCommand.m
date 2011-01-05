//
//  PBStashCommand.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBStashCommand.h"
#import "PBRemoteProgressSheet.h"

@interface PBStashCommand()
@property (nonatomic, retain) PBGitRepository *repository;
@property (nonatomic, retain) NSArray *arguments;
@end


@implementation PBStashCommand
@synthesize repository;
@synthesize arguments;

- initWithDisplayName:(NSString *) aDisplayName arguments:(NSArray *) args repository:(PBGitRepository *) repo {
	if (self = [super initWithDisplayName:aDisplayName parameters:[NSArray arrayWithObject:@"stash"]]) {
		self.arguments = args;
		self.repository = repo;
	}
	return self;
}

- (void) dealloc {
	[parameters release];
	[repository release];
	[super dealloc];
}


- (void) invoke {
	NSMutableArray *args = [[NSMutableArray alloc] initWithArray:super.parameters];
	[args addObjectsFromArray:self.arguments];
	[PBRemoteProgressSheet beginRemoteProgressSheetForArguments:args title:self.commandTitle description:self.commandDescription inRepository:self.repository];
	[args release];
}

@end
