//
//  PBWebStashController.m
//
//  Created by David Catmull on 12-06-11.
//

#import "PBWebStashController.h"
#import "PBStashContentController.h"

@implementation PBWebStashController

- (void)selectCommit:(NSString *)sha
{
	[[stashController superController] selectCommitForSha:sha];
}

- (NSArray*) menuItemsForPath:(NSString*)path
{
	return [[stashController superController] menuItemsForPaths:[NSArray arrayWithObject:path]];
}

- (NSArray*) chooseDiffParents:(NSArray *)parents
{
	return [NSArray arrayWithObject:[parents lastObject]];
}

@end
