//
//  PBDetailController.m
//  GitX
//
//  Created by Pieter de Bie on 16-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitWindowController.h"
#import "PBGitRepository.h"
#import "PBGitHistoryController.h"
#import "PBGitCommitController.h"
#import "PBTerminalUtil.h"
#import "PBCommitHookFailedSheet.h"
#import "PBGitXMessageSheet.h"
#import "PBGitSidebarController.h"
#import "PBAddRemoteSheet.h"
#import "PBGitPrefsWindowController.h"
#import "PBCreateBranchSheet.h"
#import "PBCreateTagSheet.h"
#import "PBGitDefaults.h"
#import "PBSourceViewItem.h"
#import "PBGitRevSpecifier.h"
#import "PBGitRef.h"
#import "PBError.h"
#import "PBRepositoryDocumentController.h"
#import "PBGitRepositoryDocument.h"
#import "PBRemoteProgressSheet.h"
#import "PBDiffWindowController.h"
#import "PBGitStash.h"
#import "PBGitCommit.h"
#import "PBGitWorktree.h"
#import "PBGitBinary.h"

@interface PBGitWindowController () <NSMenuItemValidation> {
	__weak PBViewController *contentController;

	PBGitSidebarController *_sidebarViewController;
	PBGitHistoryController *_historyViewController;
	PBGitCommitController *_commitViewController;

	__weak IBOutlet NSView *sourceListControlsView;
	__weak IBOutlet NSSplitView *splitView;
	__weak IBOutlet NSView *sourceSplitView;
	__weak IBOutlet NSView *contentSplitView;

	__weak IBOutlet NSTextField *statusField;
	__weak IBOutlet NSProgressIndicator *progressIndicator;
}
@end

@implementation PBGitWindowController

@dynamic document;

- (instancetype)init
{
	self = [super initWithWindowNibName:@"RepositoryWindow"];
	if (!self)
		return nil;

	return self;
}

- (PBGitRepository *)repository
{
	return [self.document repository];
}

- (void)synchronizeWindowTitleWithDocumentName
{
	[super synchronizeWindowTitleWithDocumentName];

	if ([self isWindowLoaded]) {
		// Point window proxy icon at project directory, not internal .git dir
		[[self window] setRepresentedURL:self.repository.workingDirectoryURL];
	}
}

- (void)windowWillClose:(NSNotification *)notification
{
	//	NSLog(@"Window will close!");

	[self.sidebarViewController closeView];
	[self.historyViewController closeView];
	[self.commitViewController closeView];
	_sidebarViewController = nil;
	_historyViewController = nil;
	_commitViewController = nil;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(showCommitView:)) {
		[menuItem setState:(contentController == _commitViewController) ? YES : NO];
		return ![self.repository isBareRepository];
	} else if ([menuItem action] == @selector(showHistoryView:)) {
		[menuItem setState:(contentController != _commitViewController) ? YES : NO];
		return ![self.repository isBareRepository];
	} else if (menuItem.action == @selector(fetchRemote:)) {
		return [self validateMenuItem:menuItem remoteTitle:@"Fetch “%@”" plainTitle:@"Fetch"];
	} else if (menuItem.action == @selector(fetchRemoteAndPrune:)) {
		return [self validateMenuItem:menuItem remoteTitle:@"Fetch “%@” and Prune" plainTitle:@"Fetch and Prune"];
	} else if (menuItem.action == @selector(pullRemote:)) {
		return [self validateMenuItem:menuItem remoteTitle:@"Pull From “%@”" plainTitle:@"Pull"];
	} else if (menuItem.action == @selector(pullRebaseRemote:)) {
		return [self validateMenuItem:menuItem remoteTitle:@"Pull From “%@” and Rebase" plainTitle:@"Pull and Rebase"];
	}

	return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem remoteTitle:(NSString *)localisationKeyWithRemote plainTitle:(NSString *)localizationKeyWithoutRemote
{
	PBGitRef *ref = [self selectedRef];
	if (!ref)
		return NO;

	PBGitRef *remoteRef = [self.repository remoteRefForBranch:ref error:NULL];
	if (ref.isRemote || remoteRef) {
		menuItem.title = [NSString stringWithFormat:NSLocalizedString(localisationKeyWithRemote, @""), (!remoteRef ? ref.remoteName : remoteRef.remoteName)];
		menuItem.representedObject = ref;
		return YES;
	}

	menuItem.title = NSLocalizedString(localizationKeyWithoutRemote, @"");
	return NO;
}


- (void)windowDidLoad
{
	[super windowDidLoad];

	// Explicitly set the frame using the autosave name
	// Opening the first and second documents works fine, but the third and subsequent windows aren't positioned correctly
	[[self window] setFrameUsingName:@"GitX"];
	[[self window] setRepresentedURL:self.repository.workingDirectoryURL];

	_sidebarViewController = [[PBGitSidebarController alloc] initWithRepository:self.repository superController:self];
	_historyViewController = [[PBGitHistoryController alloc] initWithRepository:self.repository superController:self];
	_commitViewController = [[PBGitCommitController alloc] initWithRepository:self.repository superController:self];

	[[_sidebarViewController view] setFrame:[sourceSplitView bounds]];
	[sourceSplitView addSubview:_sidebarViewController.view];
	[sourceListControlsView addSubview:_sidebarViewController.sourceListControlsView];

	[[statusField cell] setBackgroundStyle:NSBackgroundStyleRaised];
	[progressIndicator setUsesThreadedAnimation:YES];
}

- (void)removeAllContentSubViews
{
	if ([contentSplitView subviews])
		while ([[contentSplitView subviews] count] > 0)
			[[[contentSplitView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
}

- (void)changeContentController:(PBViewController *)controller
{
	if (!controller || (contentController == controller))
		return;

	if (contentController)
		[contentController removeObserver:self keyPath:@"status"];

	[self removeAllContentSubViews];

	contentController = controller;

	[[contentController view] setFrame:[contentSplitView bounds]];
	[contentSplitView addSubview:[contentController view]];

	//	[self setNextResponder: contentController];
	[[self window] makeFirstResponder:[contentController firstResponder]];
	[contentController updateView];
	[contentController addObserver:self
						   keyPath:@"status"
						   options:NSKeyValueObservingOptionInitial
							 block:^(MAKVONotification *notification) {
								 [self updateStatus];
							 }];
}

- (void)showCommitView:(id)sender
{
	[_sidebarViewController selectStage];
}

- (void)showHistoryView:(id)sender
{
	[_sidebarViewController selectCurrentBranch];
}

- (void)showCommitHookFailedSheet:(NSString *)messageText infoText:(NSString *)infoText commitController:(PBGitCommitController *)controller
{
	[PBCommitHookFailedSheet beginWithMessageText:messageText
										 infoText:infoText
								 commitController:controller
								completionHandler:^(id _Nonnull sheet, NSModalResponse returnCode) {
									if (returnCode != NSModalResponseOK) return;

									[self.commitViewController forceCommit:self];
								}];
}

- (void)showMessageSheet:(NSString *)messageText infoText:(NSString *)infoText
{
	[PBGitXMessageSheet beginSheetWithMessage:messageText info:infoText windowController:self];
}

- (void)showErrorSheet:(NSError *)error
{
	if ([[error domain] isEqualToString:PBGitXErrorDomain]) {
		[PBGitXMessageSheet beginSheetWithError:error windowController:self];
	} else {
		NSAlert *alert = [NSAlert alertWithError:error];

		[alert beginSheetModalForWindow:self.window
					  completionHandler:^(NSModalResponse returnCode){

					  }];
	}
}

- (void)updateStatus
{
	NSString *status = contentController.status;
	BOOL isBusy = contentController.isBusy;

	if (!status) {
		status = @"";
		isBusy = NO;
	}

	[statusField setStringValue:status];

	if (isBusy) {
		[progressIndicator startAnimation:self];
		[progressIndicator setHidden:NO];
	} else {
		[progressIndicator stopAnimation:self];
		[progressIndicator setHidden:YES];
	}
}

- (void)setHistorySearch:(NSString *)searchString mode:(PBHistorySearchMode)mode
{
	[_historyViewController setHistorySearch:searchString mode:mode];
}


- (void)openURLs:(NSArray<NSURL *> *)fileURLs
{
	if (fileURLs.count == 0) return;

	NSMutableArray *nonSubmoduleURLs = [NSMutableArray array];

	for (NSURL *fileURL in fileURLs) {
		GTSubmodule *submodule = [self.repository submoduleAtPath:fileURL.path error:NULL];
		if (!submodule) {
			[nonSubmoduleURLs addObject:fileURL];
		} else {
			NSURL *submoduleURL = [submodule.parentRepository.fileURL URLByAppendingPathComponent:submodule.path isDirectory:YES];
			[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:submoduleURL
																				   display:YES
																		 completionHandler:^(NSDocument *_Nullable document, BOOL documentWasAlreadyOpen, NSError *_Nullable error) {
																			 // Do nothing on completion.
																			 return;
																		 }];
		}
	}

	for (NSURL *fileURL in nonSubmoduleURLs) {
		[[NSWorkspace sharedWorkspace] openURL:fileURL];
	}
}

- (void)revealURLsInFinder:(NSArray<NSURL *> *)fileURLs
{
	if (fileURLs.count == 0) return;

	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}

- (void)performFetchForRef:(PBGitRef *)ref
{
	[self performFetchForRef:ref forcePrune:NO];
}

- (void)performFetchForRef:(PBGitRef *)ref forcePrune:(BOOL)forcePrune
{
	NSString *desc = nil;
	if (ref == nil) {
		desc = [NSString stringWithFormat:@"Fetching all remotes"];
	} else if (ref.isRemote || ref.isRemoteBranch) {
		desc = [NSString stringWithFormat:@"Fetching branches from remote %@", ref.remoteName];
	} else {
		desc = [NSString stringWithFormat:@"Fetching tracking branch for %@", ref.shortName];
	}
	if (forcePrune) {
		desc = [desc stringByAppendingString:@", pruning deleted branches"];
	}

	PBRemoteProgressSheet *progressSheet = [PBRemoteProgressSheet progressSheetWithTitle:@"Fetching remote…"
																			 description:desc
																		windowController:self];

	[progressSheet
		beginProgressSheetForBlock:^{
			NSError *error = nil;
			BOOL success = [self.repository fetchRemoteForRef:ref forcePrune:forcePrune error:&error];
			return (success ? nil : error);
		}
		completionHandler:^(NSError *error) {
			if (error) {
				[self showErrorSheet:error];
			}
		}];
}

- (void)performPullForBranch:(PBGitRef *)branchRef remote:(PBGitRef *)remoteRef rebase:(BOOL)rebase
{
	NSString *description = nil;
	if (!branchRef && !remoteRef) {
		NSAssert(NO, @"Asked to pull no branch from no remote");
	} else if (!branchRef) {
		description = [NSString stringWithFormat:@"Pulling all tracking branches from %@", remoteRef.remoteName];
	} else if (!remoteRef) {
		description = [NSString stringWithFormat:@"Pulling default remote for branch %@", branchRef.shortName];
	} else {
		description = [NSString stringWithFormat:@"Pulling branch %@ from remote %@", branchRef.shortName, remoteRef.remoteName];
	}

	PBRemoteProgressSheet *progressSheet = [PBRemoteProgressSheet progressSheetWithTitle:@"Pulling remote…"
																			 description:description
																		windowController:self];

	[progressSheet
		beginProgressSheetForBlock:^{
			NSError *error = nil;
			BOOL success = [self.repository pullBranch:branchRef fromRemote:remoteRef rebase:rebase error:&error];
			return success ? nil : error;
		}
		completionHandler:^(NSError *error) {
			if (error) {
				[self showErrorSheet:error];
			}
		}];
}

- (void)performPushForBranch:(PBGitRef *)branchRef toRemote:(PBGitRef *)remoteRef
{
	if ((!branchRef && !remoteRef) || (branchRef && !branchRef.isBranch && !branchRef.isRemoteBranch && !branchRef.isTag) || (remoteRef && !remoteRef.isRemote))
		return;

	NSString *description = nil;
	if (branchRef && remoteRef)
		description = [NSString stringWithFormat:@"Push %@ '%@' to remote %@", branchRef.refishType, branchRef.shortName, remoteRef.remoteName];
	else if (branchRef)
		description = [NSString stringWithFormat:@"Push %@ '%@' to default remote", branchRef.refishType, branchRef.shortName];
	else
		description = [NSString stringWithFormat:@"Push updates to remote %@", remoteRef.remoteName];

	NSString *sdesc = [NSString stringWithFormat:@"p%@", [description substringFromIndex:1]];
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = description;
	alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to %@?", sdesc];
	[alert addButtonWithTitle:NSLocalizedString(@"Push", @"Push alert - default button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Push alert - cancel button")];
	[alert setShowsSuppressionButton:YES];

	[self confirmDialog:alert
		suppressionIdentifier:@"Confirm Push"
					forAction:^{
						NSString *description = nil;
						if (branchRef && remoteRef)
							description = [NSString stringWithFormat:@"Pushing %@ '%@' to remote %@", branchRef.refishType, branchRef.shortName, remoteRef.remoteName];
						else if (branchRef)
							description = [NSString stringWithFormat:@"Pushing %@ '%@' to default remote", branchRef.refishType, branchRef.shortName];
						else
							description = [NSString stringWithFormat:@"Pushing updates to remote %@", remoteRef.remoteName];

						PBRemoteProgressSheet *progressSheet = [PBRemoteProgressSheet progressSheetWithTitle:@"Pushing remote…"
																								 description:description
																							windowController:self];

						[progressSheet
							beginProgressSheetForBlock:^{
								NSError *error = nil;
								BOOL success = [self.repository pushBranch:branchRef toRemote:remoteRef error:&error];
								return (success ? nil : error);
							}
							completionHandler:^(NSError *error) {
								if (error) {
									[self showErrorSheet:error];
								}
							}];
					}];
}

- (void)performDeleteForRemoteBranch:(PBGitRef *)ref
{
	if (![ref isRemoteBranch])
		return;

	NSString *branchName = [ref remoteBranchName];
	NSString *remoteName = [ref remoteName];

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Delete branch “%@” from remote “%@”?", @"Delete remote branch alert - message"), branchName, remoteName];
	alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"This deletes the branch on remote “%@” for everyone using it. GitX cannot undo this.", @"Delete remote branch alert - informative text"), remoteName];
	[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"Delete remote branch alert - confirm button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Delete remote branch alert - cancel and default button")];
	[self makeCancelTheDefaultButtonForDestructiveAlert:alert];

	// No suppression identifier: -confirmDialog:… skips the dialog entirely once an identifier has
	// been suppressed, and a server side delete must never happen without an explicit confirmation.
	[self confirmDialog:alert
		suppressionIdentifier:nil
					forAction:^{
						NSString *description = [NSString stringWithFormat:@"Deleting branch '%@' from remote %@", branchName, remoteName];
						PBRemoteProgressSheet *progressSheet = [PBRemoteProgressSheet progressSheetWithTitle:@"Deleting remote branch…"
																								 description:description
																							windowController:self];

						[progressSheet
							beginProgressSheetForBlock:^{
								NSError *error = nil;
								BOOL success = [self.repository deleteRemoteBranch:ref error:&error];
								return (success ? nil : error);
							}
							completionHandler:^(NSError *error) {
								if (error) {
									[self showErrorSheet:error];
								}
							}];
					}];
}

// -confirmDialog:… treats the first button as the confirming one, so the destructive button has to
// stay first. Move the return key onto the cancel button so a stray Return does not delete.
- (void)makeCancelTheDefaultButtonForDestructiveAlert:(NSAlert *)alert
{
	alert.buttons.firstObject.keyEquivalent = @"";
	alert.buttons.firstObject.hasDestructiveAction = YES;
	alert.buttons.lastObject.keyEquivalent = @"\r";
}

- (NSArray<NSURL *> *)selectedURLsFromSender:(id)sender
{
	NSArray *selectedFiles = [sender representedObject];
	if (![selectedFiles isKindOfClass:[NSArray class]] || [selectedFiles count] == 0)
		return nil;

	NSMutableArray *URLs = [NSMutableArray array];
	for (id file in selectedFiles) {
		NSString *path = file;
		// Those can be PBChangedFiles sent by PBGitIndexController. Get their path.
		if ([file respondsToSelector:@selector(path)]) {
			path = [file path];
		}

		if (![path isKindOfClass:[NSString class]])
			continue;
		[URLs addObject:[self.repository.workingDirectoryURL URLByAppendingPathComponent:path]];
	}

	return URLs;
}

#pragma mark IBActions

- (id<PBGitRefish>)refishForSender:(id)sender refishTypes:(NSArray *)types
{
	if ([sender isKindOfClass:[NSMenuItem class]]) {
		id<PBGitRefish> refish = nil;
		if ([(refish = [(NSMenuItem *)sender representedObject]) conformsToProtocol:@protocol(PBGitRefish)]) {
			if (!types || [types indexOfObject:[refish refishType]] != NSNotFound)
				return refish;
		}
		NSString *remoteName = nil;
		if ([(remoteName = [(NSMenuItem *)sender representedObject]) isKindOfClass:[NSString class]]) {
			if ([types indexOfObject:kGitXRemoteType] != NSNotFound && [self.repository.remotes indexOfObject:remoteName] != NSNotFound) {
				return [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:remoteName]];
			}
		}

		return nil;
	}

	if ([types indexOfObject:kGitXCommitType] == NSNotFound)
		return nil;

	return _historyViewController.selectedCommits.firstObject;
}

- (PBGitRef *)selectedRef
{
	return [self selectedRefForResponder:self.window.firstResponder];
}

- (PBGitRef *)selectedRefForResponder:(id)responder
{
	if (responder == self.sidebarViewController.sourceView) {
		NSOutlineView *sourceView = self.sidebarViewController.sourceView;
		PBSourceViewItem *item = [sourceView itemAtRow:sourceView.selectedRow];
		PBGitRef *ref = item.ref;
		if (ref && (item.parent == self.sidebarViewController.remotes)) {
			ref = [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:item.title]];
		}
		return ref;
	} else if (responder == _historyViewController.commitList && _historyViewController.singleCommitSelected) {
		NSMutableArray *branchCommits = [NSMutableArray array];
		for (PBGitRef *ref in _historyViewController.selectedCommits.firstObject.refs) {
			if (!ref.isBranch) continue;
			[branchCommits addObject:ref];
		}
		return (branchCommits.count == 1 ? branchCommits.firstObject : nil);
	}
	return nil;
}

- (IBAction)showGitPrefsWindow:(id)sender
{
	[PBGitPrefsWindowController showPrefsForRepository:self.repository];
}

- (IBAction)showAddRemoteSheet:(id)sender
{
	[self addRemote:sender];
}

- (IBAction)addRemote:(id)sender
{
	[PBAddRemoteSheet beginSheetWithWindowController:self
								   completionHandler:^(PBAddRemoteSheet *addSheet, NSModalResponse returnCode) {
									   if (returnCode != NSModalResponseOK) return;

									   NSString *remoteName = addSheet.remoteName.stringValue;
									   NSString *remoteURL = addSheet.remoteURL.stringValue;

									   NSString *description = [NSString stringWithFormat:@"Adding remote \"%@\"", remoteName];

									   PBRemoteProgressSheet *progressSheet = [PBRemoteProgressSheet progressSheetWithTitle:@"Adding remote"
																												description:description
																										   windowController:self];
									   [progressSheet
										   beginProgressSheetForBlock:^{
											   NSError *error = nil;
											   BOOL success = [self.repository addRemote:remoteName withURL:remoteURL error:&error];
											   return success ? nil : error;
										   }
										   completionHandler:^(NSError *error) {
											   if (error) {
												   [self showErrorSheet:error];
												   return;
											   }

											   // Now fetch that remote
											   PBGitRef *remoteRef = [self.repository refForName:remoteName];
											   [self performFetchForRef:remoteRef];
										   }];
								   }];
}

- (IBAction)deleteRef:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType, kGitXRemoteBranchType, kGitXRemoteType, kGitXTagType ]];
	if (!refish || ![refish isKindOfClass:[PBGitRef class]])
		return;

	PBGitRef *ref = (PBGitRef *)refish;

	if ([ref isRemoteBranch]) {
		[self performDeleteForRemoteBranch:ref];
		return;
	}

	NSString *ref_desc = [NSString stringWithFormat:@"%@ '%@'", [ref refishType], [ref shortName]];

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = [NSString stringWithFormat:@"Delete %@?", ref_desc];
	alert.informativeText = [NSString stringWithFormat:@"Are you sure you want to remove the %@?", ref_desc];
	[alert addButtonWithTitle:NSLocalizedString(@"Delete", @"Delete ref alert - confirm button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Delete ref alert - cancel and default button")];
	[self makeCancelTheDefaultButtonForDestructiveAlert:alert];

	[self confirmDialog:alert
		suppressionIdentifier:@"Delete Ref"
					forAction:^{
						NSError *error = nil;
						BOOL success = [self.repository deleteRef:ref error:&error];
						if (!success) {
							[self showErrorSheet:error];
						}
						return;
					}];
}

- (IBAction)fetchRemote:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType, kGitXRemoteBranchType, kGitXRemoteType ]];
	if (!refish || ![refish isKindOfClass:[PBGitRef class]])
		return;

	[self performFetchForRef:refish];
}

- (IBAction)fetchRemoteAndPrune:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType, kGitXRemoteBranchType, kGitXRemoteType ]];
	if (!refish || ![refish isKindOfClass:[PBGitRef class]])
		return;

	[self performFetchForRef:refish forcePrune:YES];
}

- (IBAction)fetchAllRemotes:(id)sender
{
	[self performFetchForRef:nil];
}

- (IBAction)fetchAllRemotesAndPrune:(id)sender
{
	[self performFetchForRef:nil forcePrune:YES];
}

- (IBAction)pullRemote:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType ]];
	if (!refish || ![refish isKindOfClass:[PBGitRef class]])
		return;

	[self performPullForBranch:refish remote:nil rebase:NO];
}

- (IBAction)pullRebaseRemote:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType ]];
	if (!refish || ![refish isKindOfClass:[PBGitRef class]])
		return;

	[self performPullForBranch:refish remote:nil rebase:YES];
}

- (IBAction)pullDefaultRemote:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType ]];
	if (!refish || ![refish isKindOfClass:[PBGitRef class]])
		return;

	[self performPullForBranch:refish remote:nil rebase:NO];
}

- (IBAction)pullRebaseDefaultRemote:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType ]];
	if (!refish || ![refish isKindOfClass:[PBGitRef class]])
		return;
	[self performPullForBranch:refish remote:nil rebase:YES];
}

- (IBAction)pushUpdatesToRemote:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXRemoteType ]];
	if (!refish || ![refish isKindOfClass:[PBGitRef class]])
		return;

	PBGitRef *remoteRef = [(PBGitRef *)refish remoteRef];

	[self performPushForBranch:nil toRemote:remoteRef];
}

- (IBAction)pushDefaultRemoteForRef:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType ]];
	if (!refish || ![refish isKindOfClass:[PBGitRef class]])
		return;

	PBGitRef *ref = (PBGitRef *)refish;

	[self performPushForBranch:ref toRemote:nil];
}

- (IBAction)pushToRemote:(id)sender
{
	NSMenuItem *remoteSubmenu = sender;
	if (![remoteSubmenu isKindOfClass:[NSMenuItem class]]) return;

	id<PBGitRefish> ref = [self refishForSender:remoteSubmenu.parentItem refishTypes:@[ kGitXBranchType ]];
	if (!ref || ![ref isKindOfClass:[PBGitRef class]])
		return;

	id<PBGitRefish> remoteRef = [self refishForSender:sender refishTypes:@[ kGitXRemoteType ]];
	if (!remoteRef || ![remoteRef isKindOfClass:[PBGitRef class]])
		return;

	[self performPushForBranch:ref toRemote:remoteRef];
}

- (IBAction)checkout:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType, kGitXRemoteBranchType, kGitXCommitType, kGitXTagType ]];
	if (!refish) return;

	NSError *error = nil;
	BOOL success = [self.repository checkoutRefish:refish error:&error];
	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)copyRefName:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:nil];
	if (!refish) return;

	NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
	[pasteboard clearContents];
	[pasteboard setString:[refish shortName] forType:NSPasteboardTypeString];
}

- (IBAction)openWorktree:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType ]];

	[self openWorktreeHoldingRef:(PBGitRef *)refish];
}

- (void)openWorktreeHoldingRef:(PBGitRef *)ref
{
	NSString *worktreePath = [self.repository pathOfWorktreeHoldingRef:ref];
	if (!worktreePath) return;

	PBGitWorktree *worktree = [self.repository worktreeHoldingRef:ref];
	if (worktree && ![[NSFileManager defaultManager] fileExistsAtPath:worktreePath]) {
		[self showMissingFolderOfWorktree:worktree];
		return;
	}

	[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:worktreePath]
																		  display:YES
																completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {
																	if (error) {
																		[self showErrorSheet:error];
																	}
																}];
}

- (NSAlert *)alertForMissingFolderOfWorktree:(PBGitWorktree *)worktree gitVersion:(NSString *)version
{
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"The worktree’s folder is missing", @"Title of the sheet when a worktree's folder is not there");
	alert.informativeText = worktree.isLocked ? [NSString stringWithFormat:NSLocalizedString(@"%@ is not there. The worktree is locked, which is how git is told a folder is on a disk that is not always connected: connect it and try again.", @"Explanation when a locked worktree's folder is not there"), worktree.path] : [NSString stringWithFormat:NSLocalizedString(@"%@ is not there. If it is on a disk that is not connected, connect it and try again. If it was deleted, Prune Worktrees… in the WORKTREES menu lets git forget it.", @"Explanation when a worktree's folder is not there"), worktree.path];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];

	if ([PBGitBinary version:version isAtLeast:@PBGitWorktreeRepairVersion]) {
		alert.informativeText = [alert.informativeText stringByAppendingFormat:@" %@", NSLocalizedString(@"If it was moved, Locate Folder… tells git where it went.", @"Explanation on the missing-folder sheet of the button that finds a moved worktree")];
		[alert addButtonWithTitle:NSLocalizedString(@"Locate Folder…", @"Button that asks where a worktree's folder was moved to")];
	}

	return alert;
}

- (void)showMissingFolderOfWorktree:(PBGitWorktree *)worktree
{
	NSAlert *alert = [self alertForMissingFolderOfWorktree:worktree gitVersion:[PBGitBinary version]];
	[alert beginSheetModalForWindow:self.window
				  completionHandler:^(NSModalResponse returnCode) {
					  if (returnCode != NSAlertSecondButtonReturn)
						  return;

					  dispatch_async(dispatch_get_main_queue(), ^{
						  [self locateFolderOfWorktree:worktree];
					  });
				  }];
}

- (IBAction)locateWorktreeFolder:(id)sender
{
	[self locateFolderOfWorktree:[sender representedObject]];
}

- (void)locateFolderOfWorktree:(PBGitWorktree *)worktree
{
	NSString *formerParent = worktree.path.stringByDeletingLastPathComponent;
	BOOL formerParentIsThere = [[NSFileManager defaultManager] fileExistsAtPath:formerParent];

	NSOpenPanel *panel = [NSOpenPanel openPanel];
	panel.message = [NSString stringWithFormat:NSLocalizedString(@"Choose the folder the worktree at %@ was moved to.", @"Message when choosing where a worktree's folder went"), worktree.path];
	panel.prompt = NSLocalizedString(@"Choose", @"Button that picks the folder a worktree was moved to");
	panel.canChooseFiles = NO;
	panel.canChooseDirectories = YES;
	panel.allowsMultipleSelection = NO;
	panel.directoryURL = formerParentIsThere ? [NSURL fileURLWithPath:formerParent] : [self folderForNewWorktrees];

	[panel beginSheetModalForWindow:self.window
				  completionHandler:^(NSModalResponse result) {
					  if (result != NSModalResponseOK)
						  return;

					  NSError *error = nil;
					  if (![self.repository repairWorktree:worktree movedTo:panel.URL.path error:&error])
						  [self showErrorSheet:error];
				  }];
}

- (IBAction)lockWorktree:(id)sender
{
	PBGitWorktree *worktree = [sender representedObject];

	NSTextField *reasonField = [NSTextField textFieldWithString:@""];
	reasonField.placeholderString = NSLocalizedString(@"Reason (optional)", @"Placeholder for the reason a worktree is being locked");
	reasonField.frame = NSMakeRect(0, 0, 300, reasonField.intrinsicContentSize.height);

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Lock the worktree at %@?", @"Title of the sheet that locks a worktree"), worktree.path];
	alert.informativeText = NSLocalizedString(@"git will not prune, move or remove a locked worktree, and shows the reason to anyone who tries.", @"Explanation on the sheet that locks a worktree");
	alert.accessoryView = reasonField;
	[alert addButtonWithTitle:NSLocalizedString(@"Lock", @"Button that locks a worktree")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
	alert.window.initialFirstResponder = reasonField;

	[alert beginSheetModalForWindow:self.window
				  completionHandler:^(NSModalResponse returnCode) {
					  if (returnCode != NSAlertFirstButtonReturn)
						  return;

					  NSError *error = nil;
					  if (![self.repository lockWorktree:worktree reason:reasonField.stringValue error:&error])
						  [self showErrorSheet:error];
				  }];
}

- (IBAction)unlockWorktree:(id)sender
{
	NSError *error = nil;
	if (![self.repository unlockWorktree:[sender representedObject] error:&error])
		[self showErrorSheet:error];
}

- (IBAction)revealWorktreeInFinder:(id)sender
{
	PBGitWorktree *worktree = [sender representedObject];

	[self revealURLsInFinder:@[ [NSURL fileURLWithPath:worktree.path] ]];
}

- (IBAction)pruneWorktrees:(id)sender
{
	NSError *error = nil;
	NSString *report = [self.repository worktreePruneReportWithError:&error];
	if (!report) {
		[self showErrorSheet:error];
		return;
	}

	NSAlert *alert = [[NSAlert alloc] init];

	if (!report.length) {
		alert.messageText = NSLocalizedString(@"Nothing to prune", @"Title of the sheet when no worktree can be pruned");
		alert.informativeText = NSLocalizedString(@"Every worktree git knows of still has its folder.", @"Explanation when no worktree can be pruned");
		[alert beginSheetModalForWindow:self.window completionHandler:nil];
		return;
	}

	alert.messageText = NSLocalizedString(@"Prune these worktrees?", @"Title of the sheet that confirms pruning worktrees");
	alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"git will forget these worktrees:\n\n%@", @"Explanation on the sheet that confirms pruning worktrees, followed by git's own list"), report];
	[alert addButtonWithTitle:NSLocalizedString(@"Prune", @"Button that prunes worktrees")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];

	[alert beginSheetModalForWindow:self.window
				  completionHandler:^(NSModalResponse returnCode) {
					  if (returnCode != NSAlertFirstButtonReturn)
						  return;

					  NSError *pruneError = nil;
					  if (![self.repository pruneWorktreesWithError:&pruneError])
						  [self showErrorSheet:pruneError];
				  }];
}

- (NSURL *)folderForNewWorktrees
{
	for (PBGitWorktree *worktree in self.repository.worktrees)
		if (worktree.isMain)
			return [[NSURL fileURLWithPath:worktree.path] URLByDeletingLastPathComponent];

	return self.repository.workingDirectoryURL.URLByDeletingLastPathComponent;
}

- (NSString *)folderNameForWorktreeOnBranch:(NSString *)branchName
{
	NSString *repositoryName = self.repository.workingDirectoryURL.lastPathComponent.stringByDeletingPathExtension;
	for (PBGitWorktree *worktree in self.repository.worktrees)
		if (worktree.isMain)
			repositoryName = worktree.path.lastPathComponent.stringByDeletingPathExtension;

	return [NSString stringWithFormat:@"%@-%@", repositoryName, [branchName stringByReplacingOccurrencesOfString:@"/" withString:@"-"]];
}

- (void)chooseFolderForWorktreeOnBranch:(NSString *)branchName message:(NSString *)message then:(void (^)(NSString *path))create
{
	NSSavePanel *panel = [NSSavePanel savePanel];
	panel.message = message;
	panel.prompt = NSLocalizedString(@"Create", @"Button that creates a worktree in the chosen folder");
	panel.nameFieldLabel = NSLocalizedString(@"Folder:", @"Label of the name field when choosing a new worktree's folder");
	panel.nameFieldStringValue = [self folderNameForWorktreeOnBranch:branchName];
	panel.directoryURL = [self folderForNewWorktrees];
	panel.canCreateDirectories = YES;
	panel.showsTagField = NO;

	[panel beginSheetModalForWindow:self.window
				  completionHandler:^(NSModalResponse result) {
					  if (result == NSModalResponseOK)
						  create(panel.URL.path);
				  }];
}

- (IBAction)checkOutInNewWorktree:(id)sender
{
	PBGitRef *branch = (PBGitRef *)[self refishForSender:sender refishTypes:@[ kGitXBranchType ]];
	if (!branch) return;

	NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Choose a folder for the worktree that checks out “%@”.", @"Message when choosing where to check a branch out in a new worktree"), branch.shortName];
	[self chooseFolderForWorktreeOnBranch:branch.shortName
								  message:message
									 then:^(NSString *path) {
										 NSError *error = nil;
										 if (![self.repository addWorktreeAtPath:path branch:branch error:&error])
											 [self showErrorSheet:error];
									 }];
}

- (IBAction)addWorktree:(id)sender
{
	NSTextField *nameField = [NSTextField textFieldWithString:@""];
	nameField.placeholderString = NSLocalizedString(@"Branch name", @"Placeholder for the name of the branch a new worktree starts");
	nameField.frame = NSMakeRect(0, 0, 300, nameField.intrinsicContentSize.height);

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"Add a worktree on a new branch", @"Title of the sheet that adds a worktree");
	alert.informativeText = NSLocalizedString(@"The branch starts at the commit checked out here. The next step chooses the worktree's folder.", @"Explanation on the sheet that adds a worktree");
	alert.accessoryView = nameField;
	[alert addButtonWithTitle:NSLocalizedString(@"Continue", @"Button that goes on to choose the new worktree's folder")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
	alert.window.initialFirstResponder = nameField;

	[alert beginSheetModalForWindow:self.window
				  completionHandler:^(NSModalResponse returnCode) {
					  NSString *name = [nameField.stringValue stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
					  if (returnCode != NSAlertFirstButtonReturn || !name.length)
						  return;

					  dispatch_async(dispatch_get_main_queue(), ^{
						  NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Choose a folder for the worktree on the new branch “%@”.", @"Message when choosing where a new worktree on a new branch goes"), name];
						  [self chooseFolderForWorktreeOnBranch:name
														message:message
														   then:^(NSString *path) {
															   NSError *error = nil;
															   if (![self.repository addWorktreeAtPath:path newBranchNamed:name error:&error])
																   [self showErrorSheet:error];
														   }];
					  });
				  }];
}

- (IBAction)removeWorktree:(id)sender
{
	PBGitWorktree *worktree = [sender representedObject];
	NSString *branchName = [worktree.branchRefName hasPrefix:@"refs/heads/"] ? [worktree.branchRefName substringFromIndex:[@"refs/heads/" length]] : nil;

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Remove the worktree at %@?", @"Title of the sheet that removes a worktree"), worktree.path];
	alert.informativeText = branchName ? [NSString stringWithFormat:NSLocalizedString(@"Its folder is deleted. The branch “%@” is kept.", @"Explanation on the sheet that removes a worktree on a branch"), branchName] : NSLocalizedString(@"Its folder is deleted.", @"Explanation on the sheet that removes a worktree with no branch");
	[alert addButtonWithTitle:NSLocalizedString(@"Remove", @"Button that removes a worktree")].hasDestructiveAction = YES;
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];

	[alert beginSheetModalForWindow:self.window
				  completionHandler:^(NSModalResponse returnCode) {
					  if (returnCode != NSAlertFirstButtonReturn)
						  return;

					  NSError *error = nil;
					  if ([self.repository removeWorktree:worktree force:NO error:&error])
						  return;

					  dispatch_async(dispatch_get_main_queue(), ^{
						  [self answerRefusalToRemoveWorktree:worktree error:error];
					  });
				  }];
}

- (void)answerRefusalToRemoveWorktree:(PBGitWorktree *)worktree error:(NSError *)error
{
	NSString *message = error.localizedFailureReason ?: error.localizedDescription;

	if ([message containsString:@"use --force"] || [message containsString:@"containing submodules"]) {
		[self offerToRemoveWorktree:worktree anywayAfter:error];
		return;
	}

	NSLog(@"git refused to remove %@ for a reason --force does not override, so only the error is shown", worktree.path);
	[self showErrorSheet:error];
}

+ (NSString *)refusalFromGitMessage:(NSString *)message
{
	NSString *refusal = [message stringByReplacingOccurrencesOfString:@", use --force to delete it" withString:@""];
	if ([refusal hasPrefix:@"fatal: "])
		refusal = [refusal substringFromIndex:[@"fatal: " length]];

	return refusal;
}

- (void)offerToRemoveWorktree:(PBGitWorktree *)worktree anywayAfter:(NSError *)refusal
{
	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = NSLocalizedString(@"git did not remove the worktree", @"Title of the sheet when git refuses to remove a worktree");
	alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"%@\n\nRemove Anyway deletes the folder all the same, and whatever in it is not committed is lost.", @"Explanation when git refuses to remove a worktree, after git's own reason"), [PBGitWindowController refusalFromGitMessage:refusal.localizedFailureReason ?: refusal.localizedDescription]];
	[alert addButtonWithTitle:NSLocalizedString(@"Remove Anyway", @"Button that removes a worktree despite what it holds")].hasDestructiveAction = YES;
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];

	[alert beginSheetModalForWindow:self.window
				  completionHandler:^(NSModalResponse returnCode) {
					  if (returnCode != NSAlertFirstButtonReturn)
						  return;

					  NSError *error = nil;
					  if (![self.repository removeWorktree:worktree force:YES error:&error])
						  [self showErrorSheet:error];
				  }];
}

- (IBAction)merge:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType, kGitXRemoteBranchType, kGitXCommitType, kGitXTagType ]];
	if (!refish) return;

	NSError *error = nil;
	BOOL success = [self.repository mergeWithRefish:refish error:&error];
	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)rebase:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXCommitType ]];
	if (!refish) return;

	NSError *error = nil;
	BOOL success = [self.repository rebaseBranch:nil onRefish:refish error:&error];
	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)rebaseHeadBranch:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXCommitType, kGitXBranchType, kGitXRemoteBranchType ]];
	if (!refish || ![refish conformsToProtocol:@protocol(PBGitRefish)])
		return;

	NSError *error = nil;
	BOOL success = [self.repository rebaseBranch:nil onRefish:refish error:&error];
	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)cherryPick:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXCommitType ]];
	if (!refish) return;

	NSError *error = nil;
	BOOL success = [self.repository cherryPickRefish:refish error:&error];
	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)resetSoft:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXBranchType, kGitXCommitType ]];
	if (!refish) return;

	NSError *error = nil;
	BOOL success = [self.repository resetRefish:GTRepositoryResetTypeSoft to:refish error:&error];
	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)stashSave:(id)sender
{
	NSError *error = nil;
	BOOL success = [self.repository stashSaveWithKeepIndex:NO error:&error];

	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)stashSaveWithKeepIndex:(id)sender
{
	NSError *error = nil;
	BOOL success = [self.repository stashSaveWithKeepIndex:YES error:&error];

	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)stashPop:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXStashType ]];
	PBGitStash *stash = [self.repository stashForRef:refish];
	if (!stash) {
		stash = self.repository.stashes.firstObject;
	}

	NSError *error = nil;
	BOOL success = [self.repository stashPop:stash error:&error];
	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)stashApply:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXStashType ]];
	PBGitStash *stash = [self.repository stashForRef:refish];
	NSError *error = nil;
	BOOL success = [self.repository stashApply:stash error:&error];

	if (!success) {
		[self showErrorSheet:error];
	}
}

- (IBAction)stashDrop:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXStashType ]];
	PBGitStash *stash = [self.repository stashForRef:refish];
	if (!stash) return;

	NSAlert *alert = [NSAlert new];
	alert.messageText = NSLocalizedString(@"Dropping stash", @"Stash drop alert - title");
	alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"You're about to drop stash %@.", @"Stash drop alert - message"), [refish shortName]];
	[alert addButtonWithTitle:NSLocalizedString(@"Drop", @"Stash drop alert - default button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Stash drop alert - cancel button")];

	[self confirmDialog:alert
		suppressionIdentifier:@"Stash Drop"
					forAction:^{
						NSError *error = nil;
						BOOL success = [self.repository stashDrop:stash error:&error];
						if (!success) {
							[self showErrorSheet:error];
						}
					}];
}

- (IBAction)openFiles:(id)sender
{
	NSArray<NSURL *> *fileURLs = [self selectedURLsFromSender:sender];
	[self openURLs:fileURLs];
}

- (IBAction)revealInFinder:(id)sender
{
	[self revealURLsInFinder:@[ self.repository.workingDirectoryURL ]];
}

- (IBAction)openInTerminal:(id)sender
{
	[PBTerminalUtil runCommand:@"git status" inDirectory:self.repository.workingDirectoryURL];
}

- (IBAction)refresh:(id)sender
{
	[contentController refresh:self];
}

- (IBAction)createBranch:(id)sender
{
	PBGitRef *currentRef = [self.repository.currentBranch ref];

	/* WIP: must check */
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:nil];
	if (!refish) {
		PBGitCommit *selectedCommit = _historyViewController.selectedCommits.firstObject;
		if (!selectedCommit || [selectedCommit hasRef:currentRef]) {
			refish = currentRef;
		} else {
			refish = selectedCommit;
		}
	}

	[PBCreateBranchSheet beginSheetWithRefish:refish
							 windowController:self
							completionHandler:^(PBCreateBranchSheet *sheet, NSModalResponse returnCode) {
								if (returnCode != NSModalResponseOK) return;

								NSError *error = nil;
								BOOL success = [self.repository createBranch:[sheet.branchNameField stringValue] atRefish:sheet.startRefish error:&error];
								if (!success) {
									[self showErrorSheet:error];
									return;
								}

								[PBGitDefaults setShouldCheckoutBranch:sheet.shouldCheckoutBranch];

								if (sheet.shouldCheckoutBranch) {
									success = [self.repository checkoutRefish:sheet.selectedRef error:&error];
									if (!success) {
										[self showErrorSheet:error];
										return;
									}
								}
							}];
}

- (IBAction)createTag:(id)sender
{
	/* WIP: must check */
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:nil];
	if (!refish) {
		PBGitCommit *selectedCommit = _historyViewController.selectedCommits.firstObject;
		if (selectedCommit)
			refish = selectedCommit;
		else
			refish = self.repository.currentBranch.ref;
	}

	[PBCreateTagSheet beginSheetWithRefish:refish
						  windowController:self
						 completionHandler:^(PBCreateTagSheet *sheet, NSModalResponse returnCode) {
							 if (returnCode != NSModalResponseOK) return;

							 NSString *tagName = [sheet.tagNameField stringValue];
							 NSString *message = [sheet.tagMessageText string];
							 NSError *error = nil;
							 BOOL success = [self.repository createTag:tagName message:message atRefish:sheet.targetRefish error:&error];
							 if (!success) {
								 [self showErrorSheet:error];
							 }
						 }];
}

- (IBAction)diffWithHEAD:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:nil];
	if (!refish)
		return;

	PBGitCommit *commit = nil;
	if ([refish isKindOfClass:[PBGitCommit class]])
		commit = refish;
	else
		commit = [self.repository commitForRef:refish];

	NSString *diff = [self.repository performDiff:commit against:nil forFiles:nil];

	[PBDiffWindowController showDiff:diff];
}

- (IBAction)stashViewDiff:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXStashType ]];
	PBGitStash *stash = [self.repository stashForRef:refish];
	[PBDiffWindowController showDiffWindowWithFiles:nil fromCommit:stash.ancestorCommit diffCommit:stash.commit];
}

- (IBAction)showTagInfoSheet:(id)sender
{
	id<PBGitRefish> refish = [self refishForSender:sender refishTypes:@[ kGitXTagType ]];
	if (!refish)
		return;

	PBGitRef *ref = (PBGitRef *)refish;

	NSError *error = nil;
	NSString *tagName = [ref tagName];
	NSString *tagRef = [@"refs/tags/" stringByAppendingString:tagName];
	GTObject *object = [self.repository.gtRepo lookUpObjectByRevParse:tagRef error:&error];
	if (!object) {
		NSLog(@"Couldn't look up ref %@:%@", tagRef, [error debugDescription]);
		return;
	}
	NSString *title = [NSString stringWithFormat:@"Info for tag: %@", tagName];
	NSString *info = @"";
	if ([object isKindOfClass:[GTTag class]]) {
		GTTag *tag = (GTTag *)object;
		info = tag.message;
	}

	[self showMessageSheet:title infoText:info];
}

@end

@implementation PBGitWindowController (PBDialog)

- (BOOL)confirmDialog:(NSAlert *)alert suppressionIdentifier:(NSString *)identifier forAction:(void (^)(void))actionBlock
{
	NSParameterAssert(alert);

	__block BOOL didAct = YES;
	if (identifier && [PBGitDefaults isDialogWarningSuppressedForDialog:identifier]) {
		actionBlock();
		return didAct;
	}

	[alert setShowsSuppressionButton:YES];

	[alert beginSheetModalForWindow:self.window
				  completionHandler:^(NSModalResponse returnCode) {
					  if (returnCode != NSAlertFirstButtonReturn) {
						  didAct = NO;
						  return;
					  }

					  if (identifier && [alert.suppressionButton state] == NSControlStateValueOn)
						  [PBGitDefaults suppressDialogWarningForDialog:identifier];

					  actionBlock();
				  }];

	return didAct;
}

@end
