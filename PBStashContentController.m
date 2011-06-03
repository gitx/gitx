//
//  PBStashContentController.h
//  GitX
//
//  Created by David Catmull on 20-06-11.
//  Copyright 2011. All rights reserved.
//

#import "PBStashContentController.h"
#import "PBGitDefaults.h"
#import "PBGitStash.h"

@implementation PBStashContentController

- (void) awakeFromNib
{
	[webController setRepository:repository];
}

- (void) showStash:(PBGitStash*)stash
{
	NSString *stashRef = [NSString stringWithFormat:@"refs/%@", [stash name]];
	NSString *stashSha = [repository shaForRef:[PBGitRef refFromString:stashRef]];
	PBGitCommit *commit = [PBGitCommit commitWithRepository:repository andSha:stashSha];

  [webController changeContentTo:commit];
}

@end

@implementation PBWebStashController
/*
- (void) changeContentTo:(PBGitStash*)stash
{
	if (stash == nil || !finishedLoading)
		return;
	
	currentStash = stash;

	// TODO: get the stash's SHA and put it in currentSha

	NSString *stashRef = [NSString stringWithFormat:@"refs/%@", [stash name]];
	NSMutableArray *taskArguments = [NSMutableArray arrayWithObjects:@"show", @"--numstat", @"--summary", @"--pretty=raw", stashRef, nil];

	if (![PBGitDefaults showWhitespaceDifferences])
		[taskArguments insertObject:@"-w" atIndex:1];

	NSFileHandle *handle = [repository handleForArguments:taskArguments];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	[nc removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:nil];
	[nc addObserver:self selector:@selector(commitDetailsLoaded:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle]; 
	[handle readToEndOfFileInBackgroundAndNotify];
}
*/
@end
