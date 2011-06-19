//
//  PBStashContentController.h
//  GitX
//
//  Created by David Catmull on 20-06-11.
//  Copyright 2011. All rights reserved.
//

#import "PBStashContentController.h"
#import "PBGitCommit.h"
#import "PBGitDefaults.h"
#import "PBGitStash.h"

const CGFloat kMinPaneSize = 32.0;

@implementation PBStashContentController

- (void) awakeFromNib
{
	[unstagedController setRepository:repository];
	[stagedController setRepository:repository];
}

- (void) showStash:(PBGitStash*)stash
{
	NSString *stashRef = [NSString stringWithFormat:@"refs/%@", [stash name]];
	NSString *stashSHA = [repository shaForRef:[PBGitRef refFromString:stashRef]];
	PBGitCommit *commit = [repository commitForSHA:stashSHA];
	NSString *indexSHA = [commit.parents objectAtIndex:1];
	PBGitCommit *indexCommit = [repository commitForSHA:indexSHA];

  [unstagedController changeContentTo:commit];
	[stagedController changeContentTo:indexCommit];
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
	return kMinPaneSize;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
	return [splitView frame].size.height - kMinPaneSize;
}

@end
