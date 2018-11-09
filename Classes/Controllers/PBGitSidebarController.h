//
//  PBGitSidebar.h
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"
#import "PBHistorySearchMode.h"

@class PBSourceViewItem;
@class PBGitHistoryController;
@class PBGitCommitController;

NS_ASSUME_NONNULL_BEGIN

@interface PBGitSidebarController : PBViewController

- (void)selectStage;
- (void)selectCurrentBranch;

- (NSMenu *)menuForRow:(NSInteger)row;
- (void)menuNeedsUpdate:(NSMenu *)menu;

- (IBAction)fetchPullPushAction:(id)sender;

@property (readonly) NSMutableArray *items;
@property (readonly) PBSourceViewItem *remotes;
@property (readonly) NSOutlineView *sourceView;
@property (readonly) NSView *sourceListControlsView;

@end

NS_ASSUME_NONNULL_END
