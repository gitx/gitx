//
//  PBGitSidebar.h
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"

@class PBSourceViewItem;
@class PBGitHistoryController;
@class PBGitCommitController;

@interface PBGitSidebarController : PBViewController /*<NSOutlineViewDelegate>*/{
	IBOutlet NSWindow *window;
	IBOutlet NSOutlineView *sourceView;
	IBOutlet NSView *sourceListControlsView;
	IBOutlet NSPopUpButton *actionButton;
	IBOutlet NSSegmentedControl *remoteControls;

    IBOutlet NSButton* svnFetchButton;
    IBOutlet NSButton* svnRebaseButton;
    IBOutlet NSButton* svnDcommitButton;
    
	NSMutableArray *items;

	/* Specific things */
	PBSourceViewItem *stage;

	PBSourceViewItem *branches, *remotes, *tags, *others, *stashes, *submodules;

	PBGitHistoryController *historyViewController;
	PBGitCommitController *commitViewController;
}

- (void) selectStage;
- (void) selectCurrentBranch;

- (NSMenu *) menuForRow:(NSInteger)row;

- (IBAction) fetchPullPushAction:(id)sender;
- (IBAction) svnFetch:(id)sender;
- (IBAction) svnRebase:(id)sender;
- (IBAction) svnDcommit:(id)sender;

- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode;

-(NSNumber *)countCommintsOf:(NSString *)range;
-(bool)remoteNeedFetch:(NSString *)remote;

@property(readonly) NSMutableArray *items;
@property(readonly) NSView *sourceListControlsView;
@property(readonly) PBGitHistoryController *historyViewController;
@property(readonly) PBGitCommitController *commitViewController;

@end
