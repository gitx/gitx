//
//  PBGitHistoryView.h
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBViewController.h"

@class PBGitCommit;
@class PBGitTree;

@class PBGitSidebarController;
@class PBWebHistoryController;
@class PBGitGradientBarView;
@class PBCommitList;
@class GLFileView;
@class GTOID;
@class PBHistorySearchController;

NS_ASSUME_NONNULL_BEGIN

@interface PBGitHistoryController : PBViewController

@property (readonly) NSArrayController *commitController;
@property (readonly) NSTreeController *treeController;
@property (readonly) PBHistorySearchController *searchController;

@property (assign) NSInteger selectedCommitDetailsIndex;
@property PBGitTree* gitTree;
@property NSArray<PBGitCommit *> *webCommits;
@property NSArray<PBGitCommit *> *selectedCommits;

@property (readonly) PBCommitList *commitList;
@property (readonly) BOOL singleCommitSelected;
@property (readonly) BOOL singleNonHeadCommitSelected;

- (BOOL)hasNonlinearPath;
- (NSMenu *)tableColumnMenu;
- (void)selectCommit:(GTOID *)commit;
- (void)updateQuicklookForce: (BOOL) force;

- (void)setHistorySearch:(NSString *)searchString mode:(PBHistorySearchMode)mode;

// Context menu methods
- (NSMenu *)contextMenuForTreeView;
- (NSArray *)menuItemsForPaths:(NSArray *)paths;
- (void)showCommitsFromTree:(id)sender;

- (IBAction)setDetailedView:(id)sender;
- (IBAction)setTreeView:(id)sender;
- (IBAction)setBranchFilter:(id)sender;

- (IBAction)refresh:(id)sender;
- (IBAction)toggleQLPreviewPanel:(id)sender;
- (IBAction)openSelectedFile:(id)sender;

// Find/Search methods
- (IBAction)selectNext:(id)sender;
- (IBAction)selectPrevious:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)copySHA:(id)sender;
- (IBAction)copyShortName:(id)sender;
- (IBAction)copyPatch:(id)sender;

@end

@interface PBGitHistoryController (PBContextMenu)

- (NSArray *)menuItemsForRef:(PBGitRef *)refs;
- (NSArray *)menuItemsForCommits:(NSArray<PBGitCommit *> *)commits;

@end

NS_ASSUME_NONNULL_END

