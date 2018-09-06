//
//  PBLabelController.m
//  GitX
//
//  Created by Pieter de Bie on 21-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBRefController.h"
#import "PBGitRevisionCell.h"
#import "PBRefMenuItem.h"
#import "PBGitDefaults.h"
#import "PBDiffWindowController.h"
#import "PBGitRevSpecifier.h"
#import "PBGitStash.h"
#import "GitXCommitCopier.h"

@implementation PBRefController

#pragma mark Contextual menus

- (NSArray<NSMenuItem *> *) menuItemsForRef:(PBGitRef *)ref
{
	return [NSMenuItem pb_defaultMenuItemsForRef:ref inRepository:historyController.repository];
}

- (NSArray<NSMenuItem *> *) menuItemsForCommits:(NSArray<PBGitCommit *> *)commits
{
	return [NSMenuItem pb_defaultMenuItemsForCommits:commits];
}

- (NSArray<NSMenuItem *> *)menuItemsForRow:(NSInteger)rowIndex
{
	NSArray<PBGitCommit *> *commits = [commitController arrangedObjects];
	if ([commits count] <= rowIndex)
		return nil;

	return [self menuItemsForCommits:@[[commits objectAtIndex:rowIndex]]];
}

- (void)dealloc {
    historyController = nil;
}

@end
