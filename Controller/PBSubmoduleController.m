//
//  PBSubmoduleController.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-27.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBSubmoduleController.h"
#import "PBGitRepository.h"
#import "PBOpenDocumentCommand.h"

@interface PBSubmoduleController()
@property (nonatomic, retain) NSArray *submodules;
@end


@implementation PBSubmoduleController
@synthesize submodules;

- (id) initWithRepository:(PBGitRepository *) repo {
    if ((self = [super init])){
        repository = [repo retain];
    }
    return self;
}

- (void)dealloc {
    [repository release];
    [submodules release];
    [super dealloc];
}

- (void) reload {
	NSArray *arguments = [NSArray arrayWithObjects:@"submodule", @"status", @"--recursive", nil];
	NSString *output = [repository outputInWorkdirForArguments:arguments];
	NSArray *lines = [output componentsSeparatedByString:@"\n"];
	
	NSMutableArray *loadedSubmodules = [[NSMutableArray alloc] initWithCapacity:[lines count]];
	
	for (NSString *submoduleLine in lines) {
		if ([submoduleLine length] == 0)
			continue;
		PBGitSubmodule *submodule = [[PBGitSubmodule alloc] initWithRawSubmoduleStatusString:submoduleLine];
		[loadedSubmodules addObject:submodule];
	}
	
	NSMutableArray *groupedSubmodules = [[NSMutableArray alloc] init];
	for (PBGitSubmodule *submodule in loadedSubmodules) {
		BOOL added = NO;
		for (PBGitSubmodule *addedItem in groupedSubmodules) {
			if ([[submodule path] hasPrefix:[addedItem path]]) {
				[addedItem addSubmodule:submodule];
				added = YES;
			}
		}
		if (!added) {
			[groupedSubmodules addObject:submodule];
		}
	}
	
	
	self.submodules = loadedSubmodules;
}

#pragma mark -
#pragma mark Actions

- (void) addNewSubmodule {
	//TODO implement
}

- (void) initializeAllSubmodules {
	NSArray *parameters = [NSArray arrayWithObjects:@"submodule", @"init", nil];
	PBCommand *initializeSubmodules = [[PBCommand alloc] initWithDisplayName:@"Initialize All Submodules" parameters:parameters repository:repository];
	initializeSubmodules.commandTitle = initializeSubmodules.displayName;
	initializeSubmodules.commandDescription = @"Initializing submodules";
	[initializeSubmodules invoke];
	[initializeSubmodules release];
}

- (void) updateAllSubmodules {
	NSArray *parameters = [NSArray arrayWithObjects:@"submodule", @"update", nil];
	PBCommand *initializeSubmodules = [[PBCommand alloc] initWithDisplayName:@"Update All Submodules" parameters:parameters repository:repository];
	initializeSubmodules.commandTitle = initializeSubmodules.displayName;
	initializeSubmodules.commandDescription = @"Updating submodules";
	[initializeSubmodules invoke];
	[initializeSubmodules release];
}

- (NSArray *) menuItems {
	NSMutableArray *items = [[NSMutableArray alloc] init];
	[items addObject:[[NSMenuItem alloc] initWithTitle:@"Add Submodule..." action:@selector(addNewSubmodule) keyEquivalent:@""]];
	[items addObject:[[NSMenuItem alloc] initWithTitle:@"Initialize All Submodules" action:@selector(initializeAllSubmodules) keyEquivalent:@""]];
	[items addObject:[[NSMenuItem alloc] initWithTitle:@"Update All Submodules" action:@selector(updateAllSubmodules) keyEquivalent:@""]];
	
	for (NSMenuItem *item in items) {
		[item setTarget:self];
	}
	
	return items;
}

- (PBCommand *) defaultCommandForSubmodule:(PBGitSubmodule *) submodule {
	return [self commandForOpeningSubmodule:submodule];
}

- (PBCommand *) commandForOpeningSubmodule:(PBGitSubmodule *) submodule {
	if (!([submodule path] && [submodule submoduleState] != PBGitSubmoduleStateNotInitialized)) {
		return nil;
	}
	NSString *repoPath = [repository workingDirectory];
	NSString *path = [repoPath stringByAppendingPathComponent:[submodule path]];
	
	PBOpenDocumentCommand *command = [[PBOpenDocumentCommand alloc] initWithDocumentAbsolutePath:path];
	command.commandTitle = command.displayName;
	command.commandDescription = @"Opening document";
	return [command autorelease];
}

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem {
	BOOL shouldBeEnabled = YES;
	SEL action = [menuItem action];
	if (action == @selector(addNewSubmodule)) {
		shouldBeEnabled = NO;
		//TODO implementation missing
	} else {
		shouldBeEnabled = [self.submodules count] > 0;
	}
	return shouldBeEnabled;
}

@end
