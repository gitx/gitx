//
//  PBGitCommitController.h
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"

@class PBGitIndexController;
@class PBIconAndTextCell;
@class PBWebChangesController;
@class PBGitIndex;
@class PBNiceSplitView;
@class PBCommitMessageView;

@interface PBGitCommitController : PBViewController {
	IBOutlet PBCommitMessageView *commitMessageView;

	BOOL stashKeepIndex;

	IBOutlet NSArrayController *unstagedFilesController;
	IBOutlet NSArrayController *cachedFilesController;
	IBOutlet NSArrayController *trackedFilesController;

	IBOutlet NSTabView *controlsTabView;
	IBOutlet NSButton *commitButton;
	IBOutlet NSButton *stashButton;

	IBOutlet PBGitIndexController *indexController;
	IBOutlet PBWebChangesController *webController;
	IBOutlet PBNiceSplitView *commitSplitView;
}

@property(assign) BOOL stashKeepIndex;

- (IBAction) refresh:(id) sender;
- (IBAction) commit:(id) sender;
- (IBAction) forceCommit:(id) sender;
- (IBAction) signOff:(id)sender;
- (IBAction) stashChanges:(id) sender;

- (PBGitIndex *) index;

- (NSView *) nextKeyViewFor:(NSView *)view;
- (NSView *) previousKeyViewFor:(NSView *)view;

@end
