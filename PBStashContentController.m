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
