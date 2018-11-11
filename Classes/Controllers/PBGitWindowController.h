//
//  PBDetailController.h
//  GitX
//
//  Created by Pieter de Bie on 16-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBHistorySearchMode.h"

@class PBViewController;
@class PBGitSidebarController;
@class PBGitCommitController;
@class PBGitHistoryController;
@class PBGitRepository;
@class RJModalRepoSheet;
@class PBGitRef;
@class PBGitCommit;
@class PBGitRepositoryDocument;

NS_ASSUME_NONNULL_BEGIN

@interface PBGitWindowController : NSWindowController <NSWindowDelegate>

@property (nonatomic, strong) PBGitRepository *repository;
/* This is assign because that's what NSWindowController says :-S */
@property (assign) PBGitRepositoryDocument *document;
@property (readonly, nullable) PBGitHistoryController *historyViewController;
@property (readonly, nullable) PBGitCommitController *commitViewController;
@property (readonly, nullable) PBGitSidebarController *sidebarViewController;

- (instancetype)init;

- (void)changeContentController:(PBViewController *)controller;

- (void)showCommitHookFailedSheet:(NSString *)messageText infoText:(NSString *)infoText commitController:(PBGitCommitController *)controller GITX_DEPRECATED;

- (void)showMessageSheet:(NSString *)messageText infoText:(NSString *)infoText;
- (void)showErrorSheet:(NSError *)error;


- (void)openURLs:(NSArray <NSURL *> *)fileURLs;
- (void)revealURLsInFinder:(NSArray <NSURL *> *)fileURLs;

- (IBAction)showCommitView:(id)sender;
- (IBAction)showHistoryView:(id)sender;
- (IBAction)openFiles:(id)sender;
- (IBAction)revealInFinder:(id)sender;
- (IBAction)openInTerminal:(id)sender;
- (IBAction)refresh:(id)sender;

- (IBAction)checkout:(id)sender;
- (IBAction)createBranch:(id)sender;
- (IBAction)createTag:(id)sender;
- (IBAction)merge:(id)sender;
- (IBAction)deleteRef:(id)sender;
- (IBAction)rebase:(id)sender;
- (IBAction)rebaseHeadBranch:(id)sender;
- (IBAction)cherryPick:(id)sender;
- (IBAction)resetSoft:(id)sender;

- (IBAction)showAddRemoteSheet:(id)sender GITX_DEPRECATED;
- (IBAction)addRemote:(id)sender;
- (IBAction)fetchRemote:(id)sender;
- (IBAction)fetchAllRemotes:(id)sender;

- (IBAction)pullRemote:(id)sender;
- (IBAction)pullRebaseRemote:(id)sender;
- (IBAction)pullDefaultRemote:(id)sender;
- (IBAction)pullRebaseDefaultRemote:(id)sender;

- (IBAction)pushUpdatesToRemote:(id)sender;
- (IBAction)pushDefaultRemoteForRef:(id)sender;
- (IBAction)pushToRemote:(id)sender;

- (IBAction)stashSave:(id) sender;
- (IBAction)stashSaveWithKeepIndex:(id) sender;
- (IBAction)stashPop:(id) sender;
- (IBAction)stashApply:(id)sender;
- (IBAction)stashDrop:(id)sender;

- (IBAction)diffWithHEAD:(id)sender;
- (IBAction)stashViewDiff:(id)sender;
- (IBAction)showTagInfoSheet:(id)sender;

- (void)setHistorySearch:(NSString *)searchString mode:(PBHistorySearchMode)mode;

- (void)performFetchForRef:(nullable PBGitRef *)ref;
- (void)performPullForBranch:(PBGitRef *)branchRef remote:(nullable PBGitRef *)remoteRef rebase:(BOOL)rebase;
- (void)performPushForBranch:(nullable PBGitRef *)branchRef toRemote:(nullable PBGitRef *)remoteRef;

@end

@interface PBGitWindowController (PBDialog)
/**
 * Ask the user to confirm an action.
 *
 * @param alert The alert to show.
 * @param identifier The user default to check to suppress the alert completely.
 * @param actionBlock The action to perform.
 * @return YES if the action was performed, NO if the user cancelled.
 */
- (BOOL)confirmDialog:(NSAlert *)alert suppressionIdentifier:(nullable NSString *)identifier forAction:(void (^)(void))actionBlock;
@end

NS_ASSUME_NONNULL_END
