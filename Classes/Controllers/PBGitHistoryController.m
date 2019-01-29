//
//  PBGitHistoryView.m
//  GitX
//
//  Created by Pieter de Bie on 19-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Quartz/Quartz.h>

#import "PBGitHistoryController.h"
#import "PBGitTree.h"
#import "PBGitRef.h"
#import "PBGitHistoryList.h"
#import "PBGitRevSpecifier.h"
#import "PBWebHistoryController.h"
#import "PBCommitList.h"
#import "PBGitGradientBarView.h"
#import "PBDiffWindowController.h"
#import "PBGitDefaults.h"
#import "PBHistorySearchController.h"
#import "PBGitRepositoryWatcher.h"
#import "PBQLTextView.h"
#import "GLFileView.h"
#import "GitXCommitCopier.h"
#import "NSSplitView+GitX.h"
#import "PBGitRevisionRow.h"
#import "PBGitRevisionCell.h"
#import "PBGitStash.h"

#define kHistorySelectedDetailIndexKey @"PBHistorySelectedDetailIndex"
#define kHistoryDetailViewIndex 0
#define kHistoryTreeViewIndex 1

@interface PBGitHistoryController () <NSTableViewDelegate> {
	IBOutlet NSArrayController *commitController;
	IBOutlet NSTreeController *treeController;
	IBOutlet PBWebHistoryController *webHistoryController;
	IBOutlet GLFileView *fileView;
	IBOutlet PBHistorySearchController *searchController;

	__weak IBOutlet NSSearchField *searchField;
	__weak IBOutlet NSOutlineView *fileBrowser;
	__weak IBOutlet PBCommitList *commitList;
	__weak IBOutlet NSSplitView *historySplitView;
	__weak IBOutlet PBGitGradientBarView *upperToolbarView;
	__weak IBOutlet PBGitGradientBarView *scopeBarView;
	__weak IBOutlet NSButton *allBranchesFilterItem;
	__weak IBOutlet NSButton *localRemoteBranchesFilterItem;
	__weak IBOutlet NSButton *selectedBranchFilterItem;
	__weak IBOutlet id webView;

	NSArray *currentFileBrowserSelectionPath;
	NSInteger selectedCommitDetailsIndex;
	BOOL forceSelectionUpdate;
	PBGitTree *gitTree;
	NSArray<PBGitCommit *> *webCommits;
	NSArray<PBGitCommit *> *selectedCommits;
}

- (void) updateBranchFilterMatrix;
- (void) restoreFileBrowserSelection;
- (void) saveFileBrowserSelection;

@end


@implementation PBGitHistoryController
@synthesize webCommits, gitTree, commitController;
@synthesize searchController;
@synthesize commitList;
@synthesize treeController;
@synthesize selectedCommits;

- (void)awakeFromNib
{
	/* FIXME: Be careful with this method: since PBGitRevisionRow & PBGitRevisionCell
	 * have this controller in their outlets, this method is called *really* often
	 * (vs. the expected *once*)
	 */
}

- (void)loadView {
	[super loadView];

	[historySplitView pb_restoreAutosavedPositions];

	self.selectedCommitDetailsIndex = [[NSUserDefaults standardUserDefaults] integerForKey:kHistorySelectedDetailIndexKey];

	[commitController addObserver:self keyPath:@"selection" options:0 block:^(MAKVONotification *notification) {
		PBGitHistoryController *observer = notification.observer;
		[observer updateKeys];
	}];

	[commitController addObserver:self keyPath:@"arrangedObjects.@count" options:NSKeyValueObservingOptionInitial block:^(MAKVONotification *notification) {
		PBGitHistoryController *observer = notification.observer;
		[observer reselectCommitAfterUpdate];
	}];

	[treeController addObserver:self keyPath:@"selection" options:0 block:^(MAKVONotification *notification) {
		PBGitHistoryController *observer = notification.observer;
		[observer updateQuicklookForce: NO];
		[observer saveFileBrowserSelection];
	}];

	[repository.revisionList addObserver:self keyPath:@"isUpdating" options:0 block:^(MAKVONotification *notification) {
		PBGitHistoryController *observer = notification.observer;
		[observer reselectCommitAfterUpdate];
	}];

	[repository addObserver:self keyPath:@"currentBranch" options:0 block:^(MAKVONotification *notification) {
		PBGitHistoryController *observer = notification.observer;
		// Reset the sorting
		if ([[observer.commitController sortDescriptors] count]) {
			[observer.commitController setSortDescriptors:[NSArray array]];
			[observer.commitController rearrangeObjects];
		}

		[observer updateBranchFilterMatrix];
	}];

	[repository addObserver:self keyPath:@"refs" options:0 block:^(MAKVONotification *notification) {
		PBGitHistoryController *observer = notification.observer;
		[observer.commitController rearrangeObjects];
	}];

	[repository addObserver:self keyPath:@"currentBranchFilter" options:0 block:^(MAKVONotification *notification) {
		PBGitHistoryController *observer = notification.observer;
		[PBGitDefaults setBranchFilter:observer.repository.currentBranchFilter];
		[observer updateBranchFilterMatrix];
	}];

	forceSelectionUpdate = YES;
	NSSize cellSpacing = [commitList intercellSpacing];
	cellSpacing.height = 0;
	[commitList setIntercellSpacing:cellSpacing];
	[fileBrowser setTarget:self];
	[fileBrowser setDoubleAction:@selector(openSelectedFile:)];

	if (!repository.currentBranch) {
		[repository reloadRefs];
		[repository readCurrentBranch];
	}
	else
		[repository lazyReload];

    if (![repository hasSVNRemote])
    {
        // Remove the SVN revision table column for repositories with no SVN remote configured
        [commitList removeTableColumn:[commitList tableColumnWithIdentifier:@"GitSVNRevision"]];
    }

	// Set a sort descriptor for the subject column in the history list, as
	// It can't be sorted by default (because it's bound to a PBGitCommit)
	[[commitList tableColumnWithIdentifier:@"SubjectColumn"] setSortDescriptorPrototype:[[NSSortDescriptor alloc] initWithKey:@"subject" ascending:YES]];
	// Add a menu that allows a user to select which columns to view
	[[commitList headerView] setMenu:[self tableColumnMenu]];

	[commitList registerForDraggedTypes:[NSArray arrayWithObject:@"PBGitRef"]];

	[upperToolbarView setTopShade:237/255.0f bottomShade:216/255.0f];
	[scopeBarView setTopColor:[NSColor colorWithCalibratedHue:0.579 saturation:0.068 brightness:0.898 alpha:1.000]
				  bottomColor:[NSColor colorWithCalibratedHue:0.579 saturation:0.119 brightness:0.765 alpha:1.000]];
	[self updateBranchFilterMatrix];

	// listen for updates
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_repositoryUpdatedNotification:) name:PBGitRepositoryEventNotification object:repository];

	[super awakeFromNib];
}

- (void) _repositoryUpdatedNotification:(NSNotification *)notification {
    PBGitRepositoryWatcherEventType eventType = [(NSNumber *)[[notification userInfo] objectForKey:kPBGitRepositoryEventTypeUserInfoKey] unsignedIntValue];
    if(eventType & PBGitRepositoryWatcherEventTypeGitDirectory){
      // refresh if the .git repository is modified
      [self refresh:self];
    }
}

- (void)reselectCommitAfterUpdate {
	[self updateStatus];

	if ([self.repository.currentBranch isSimpleRef])
		[self selectCommit:[self.repository OIDForRef:self.repository.currentBranch.ref]];
	else
		[self selectCommit:self.firstCommit.OID];
}

- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
	NSTableRowView *view = [tableView rowViewAtRow:row makeIfNecessary:NO];
	
	if (view) {
		return view;
	}

	PBGitRevisionRow *rowView = [PBGitRevisionRow new];

	rowView.controller = self;

	return rowView;
}

- (void) updateKeys
{
	NSArray<PBGitCommit *> *newSelectedCommits = commitController.selectedObjects;
	if  (![self.selectedCommits isEqualToArray:newSelectedCommits]) {
		self.selectedCommits = newSelectedCommits;
	}
	
	PBGitCommit *firstSelectedCommit = self.selectedCommits.firstObject;
	
	if (self.selectedCommitDetailsIndex == kHistoryTreeViewIndex) {
		self.gitTree = firstSelectedCommit.tree;
		[self restoreFileBrowserSelection];
	}
	else {
		// kHistoryDetailViewIndex
		if (![self.webCommits isEqualToArray:self.selectedCommits]) {
			self.webCommits = self.selectedCommits;
		}
	}
}

- (BOOL) singleCommitSelected
{
	return self.selectedCommits.count == 1;
}

+ (NSSet *) keyPathsForValuesAffectingSingleCommitSelected {
	return [NSSet setWithObjects:@"selectedCommits", nil];
}

- (BOOL) singleNonHeadCommitSelected
{
	return self.singleCommitSelected
		&& ![self.selectedCommits.firstObject isOnHeadBranch];
}

+ (NSSet *) keyPathsForValuesAffectingSingleNonHeadCommitSelected {
	return [self keyPathsForValuesAffectingSingleCommitSelected];
}

- (void) updateBranchFilterMatrix
{
	if ([repository.currentBranch isSimpleRef]) {
		[allBranchesFilterItem setEnabled:YES];
		[localRemoteBranchesFilterItem setEnabled:YES];

		NSInteger filter = repository.currentBranchFilter;
		[allBranchesFilterItem setState:(filter == kGitXAllBranchesFilter)];
		[localRemoteBranchesFilterItem setState:(filter == kGitXLocalRemoteBranchesFilter)];
		[selectedBranchFilterItem setState:(filter == kGitXSelectedBranchFilter)];
	}
	else {
		[allBranchesFilterItem setState:NO];
		[localRemoteBranchesFilterItem setState:NO];

		[allBranchesFilterItem setEnabled:NO];
		[localRemoteBranchesFilterItem setEnabled:NO];

		[selectedBranchFilterItem setState:YES];
	}

	[selectedBranchFilterItem setTitle:[repository.currentBranch title]];
	[selectedBranchFilterItem sizeToFit];

	[localRemoteBranchesFilterItem setTitle:[[repository.currentBranch ref] isRemote]
		? NSLocalizedString(@"Remote", @"Filter button for all remote commits in history view")
		: NSLocalizedString(@"Local", @"Filter button for all local commits in history view")];
}

- (PBGitCommit *) firstCommit
{
	NSArray *arrangedObjects = [commitController arrangedObjects];
	if ([arrangedObjects count] > 0)
		return [arrangedObjects objectAtIndex:0];

	return nil;
}

- (BOOL)isCommitSelected
{
	return [self.selectedCommits isEqualToArray:[commitController selectedObjects]];
}

- (void) setSelectedCommitDetailsIndex:(NSInteger)detailsIndex
{
	if (selectedCommitDetailsIndex == detailsIndex)
		return;

	selectedCommitDetailsIndex = detailsIndex;
	[[NSUserDefaults standardUserDefaults] setInteger:selectedCommitDetailsIndex forKey:kHistorySelectedDetailIndexKey];
	forceSelectionUpdate = YES;
	[self updateKeys];
}

- (NSInteger) selectedCommitDetailsIndex
{
	return selectedCommitDetailsIndex;
}

- (void) updateStatus
{
	self.isBusy = repository.revisionList.isUpdating;
	self.status = [NSString stringWithFormat:@"%lu commits loaded", [[commitController arrangedObjects] count]];
}

- (void) restoreFileBrowserSelection
{
	if (self.selectedCommitDetailsIndex != kHistoryTreeViewIndex)
		return;

	NSArray *children = [treeController content];
	if ([children count] == 0)
		return;

	NSIndexPath *path = [[NSIndexPath alloc] init];
	if ([currentFileBrowserSelectionPath count] == 0)
		path = [path indexPathByAddingIndex:0];
	else {
		for (NSString *pathComponent in currentFileBrowserSelectionPath) {
			PBGitTree *child = nil;
			NSUInteger childIndex = 0;
			for (child in children) {
				if ([child.path isEqualToString:pathComponent]) {
					path = [path indexPathByAddingIndex:childIndex];
					children = child.children;
					break;
				}
				childIndex++;
			}
			if (!child)
				return;
		}
	}

	[treeController setSelectionIndexPath:path];
}

- (void) saveFileBrowserSelection
{
	NSArray *objects = [treeController selectedObjects];
	NSArray *content = [treeController content];

	if ([objects count] && [content count]) {
		PBGitTree *treeItem = [objects objectAtIndex:0];
		currentFileBrowserSelectionPath = [treeItem.fullPath componentsSeparatedByString:@"/"];
	}
}

- (IBAction) openSelectedFile:(id)sender
{
	NSArray* selectedFiles = [treeController selectedObjects];
	if ([selectedFiles count] == 0)
		return;
	PBGitTree* tree = [selectedFiles objectAtIndex:0];
	NSString* name = [tree tmpFileNameForContents];
	[[NSWorkspace sharedWorkspace] openFile:name];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = menuItem.action;

    if (action == @selector(setDetailedView:)) {
		[menuItem setState:(self.selectedCommitDetailsIndex == kHistoryDetailViewIndex) ? NSOnState : NSOffState];
    } else if (action == @selector(setTreeView:)) {
		[menuItem setState:(self.selectedCommitDetailsIndex == kHistoryTreeViewIndex) ? NSOnState : NSOffState];
	}
	
	if ([self respondsToSelector:action]) {
		if (action == @selector(createBranch:) || action == @selector(createTag:)) {
			return self.singleCommitSelected;
		}
		
        return YES;
	}

	if (action == @selector(copy:)
		|| action == @selector(copySHA:)
		|| action == @selector(copyShortName:)
		|| action == @selector(copyPatch:)) {
		return self.commitController.selectedObjects.count > 0;
	}
	
    return [[self nextResponder] validateMenuItem:menuItem];
}

- (IBAction) setDetailedView:(id)sender
{
	self.selectedCommitDetailsIndex = kHistoryDetailViewIndex;
	forceSelectionUpdate = YES;
}

- (IBAction) setTreeView:(id)sender
{
	self.selectedCommitDetailsIndex = kHistoryTreeViewIndex;
	forceSelectionUpdate = YES;
}

- (IBAction) setBranchFilter:(id)sender
{
	repository.currentBranchFilter = [(NSView*)sender tag];
	[PBGitDefaults setBranchFilter:repository.currentBranchFilter];
	[self updateBranchFilterMatrix];
	forceSelectionUpdate = YES;
}

- (void)keyDown:(NSEvent*)event
{
	if ([[event charactersIgnoringModifiers] isEqualToString: @"f"] && [event modifierFlags] & NSAlternateKeyMask && [event modifierFlags] & NSCommandKeyMask)
		[superController.window makeFirstResponder: searchField];
	else
		[super keyDown: event];
}

- (void)setHistorySearch:(NSString *)searchString mode:(PBHistorySearchMode)mode
{
	[searchController setHistorySearch:searchString mode:mode];
}

- (IBAction)performFindPanelAction:(id)sender
{
	[self.windowController.window makeFirstResponder:self->searchField];
}

// NSSearchField (actually textfields in general) prevent the normal Find operations from working. Setup custom actions for the
// next and previous menuitems (in MainMenu.nib) so they will work when the search field is active. When searching for text in
// a file make sure to call the Find panel's action method instead.
- (IBAction)selectNext:(id)sender
{
	NSResponder *firstResponder = [[[self view] window] firstResponder];
	if ([firstResponder isKindOfClass:[PBQLTextView class]]) {
		[(PBQLTextView *)firstResponder performFindPanelAction:sender];
		return;
	}

	[searchController selectNextResult];
}
- (IBAction)selectPrevious:(id)sender
{
	NSResponder *firstResponder = [[[self view] window] firstResponder];
	if ([firstResponder isKindOfClass:[PBQLTextView class]]) {
		[(PBQLTextView *)firstResponder performFindPanelAction:sender];
		return;
	}

	[searchController selectPreviousResult];
}

- (IBAction) selectParentCommit:(id)sender
{
	NSArray *selectedObjects = commitController.selectedObjects;
	if (selectedObjects.count != 1) return;

	PBGitCommit *selectedCommit = selectedObjects[0];

	NSArray <GTOID *> *parents = selectedCommit.parents;
	/* TODO: This is a merge commit. It would be nice to choose the parent with
	 * the most commits, but for now we will use whatever commit is our first parent.
	 */

	[self selectCommit:parents[0]];
}

- (IBAction) copy:(id)sender
{
	[GitXCommitCopier putStringToPasteboard:[GitXCommitCopier toSHAAndHeadingString:commitController.selectedObjects]];
}

- (IBAction) copySHA:(id)sender
{
	[GitXCommitCopier putStringToPasteboard:[GitXCommitCopier toFullSHA:commitController.selectedObjects]];
}

- (IBAction) copyShortName:(id)sender
{
	[GitXCommitCopier putStringToPasteboard:[GitXCommitCopier toShortName:commitController.selectedObjects]];
}

- (IBAction) copyPatch:(id)sender
{
	[GitXCommitCopier putStringToPasteboard:[GitXCommitCopier toPatch:commitController.selectedObjects]];
}

- (IBAction) toggleQLPreviewPanel:(id)sender
{
	if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible])
		[[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
	else
		[[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
}

- (void) updateQuicklookForce:(BOOL)force
{
	if (!force && (![QLPreviewPanel sharedPreviewPanelExists] || ![[QLPreviewPanel sharedPreviewPanel] isVisible]))
		return;

	[[QLPreviewPanel sharedPreviewPanel] reloadData];
}

- (IBAction) refresh:(id)sender
{
	[repository forceUpdateRevisions];
}

- (void) updateView
{
	[self updateKeys];
}

- (NSResponder *)firstResponder;
{
	return commitList;
}

- (void) scrollSelectionToTopOfViewFrom:(NSInteger)oldIndex
{
	if (oldIndex == NSNotFound)
		oldIndex = 0;

	NSInteger newIndex = commitController.selectionIndexes.firstIndex;

	if (newIndex > oldIndex) {
        CGFloat sviewHeight = commitList.superview.bounds.size.height;
        CGFloat rowHeight = commitList.rowHeight;
		NSInteger visibleRows = lround(sviewHeight / rowHeight);
		newIndex += (visibleRows - 1);
		if (newIndex >= [commitController.content count])
			newIndex = [commitController.content count] - 1;
	}

    if (newIndex != oldIndex) {
        commitList.useAdjustScroll = YES;
    }

	[commitList scrollRowToVisible:newIndex];
    commitList.useAdjustScroll = NO;
}

- (NSArray *) selectedObjectsForOID:(GTOID *)commitOID
{
	NSPredicate *selection = [NSPredicate predicateWithFormat:@"OID == %@", commitOID];
	NSArray *selectionCommits = [[commitController content] filteredArrayUsingPredicate:selection];

	if ((selectionCommits.count == 0) && [self firstCommit] != nil) {
		selectionCommits = @[[self firstCommit]];
	}
	
	return selectionCommits;
}

- (void)selectCommit:(GTOID *)commitOID
{
	if (!forceSelectionUpdate && [[[commitController.selectedObjects lastObject] OID] isEqual:commitOID]) {
		return;
	}

	NSArray *selectedObjects = [self selectedObjectsForOID:commitOID];
	[commitController setSelectedObjects:selectedObjects];

	NSInteger oldIndex = [[commitController selectionIndexes] firstIndex];
	[self scrollSelectionToTopOfViewFrom:oldIndex];

	forceSelectionUpdate = NO;
}

- (BOOL) hasNonlinearPath
{
	return [commitController filterPredicate] || [[commitController sortDescriptors] count] > 0;
}

- (void)closeView
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[webHistoryController closeView];
	[fileView closeView];

	[super closeView];
}

#pragma mark Table Column Methods
- (NSMenu *)tableColumnMenu
{
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@""];
	for (NSTableColumn *column in [commitList tableColumns]) {
		NSMenuItem *item = [[NSMenuItem alloc] init];
		[item setTitle:[[column headerCell] stringValue]];
		[item bind:@"value"
		  toObject:column
	   withKeyPath:@"hidden"
		   options:[NSDictionary dictionaryWithObject:@"NSNegateBoolean" forKey:NSValueTransformerNameBindingOption]];
		[menu addItem:item];
	}
	return menu;
}

#pragma mark Tree Context Menu Methods

- (void)showCommitsFromTree:(id)sender
{
	NSString *searchString = [(NSArray *)[sender representedObject] componentsJoinedByString:@" "];
	[self setHistorySearch:searchString mode:PBHistorySearchModePath];
}

- (void) checkoutFiles:(id)sender
{
	NSMutableArray *files = [NSMutableArray array];
	for (NSString *filePath in [sender representedObject])
		[files addObject:[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];

	NSError *error = nil;
	BOOL success = [repository checkoutFiles:files fromRefish:self.selectedCommits.firstObject error:&error];
	if (!success) {
		[self.windowController showErrorSheet:error];
	}

}

- (void) diffFilesAction:(id)sender
{
	/* TODO: Move that to the document */
	[PBDiffWindowController showDiffWindowWithFiles:[sender representedObject] fromCommit:self.selectedCommits.firstObject diffCommit:nil];
}

#pragma mark -
#pragma mark History table view delegate

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
	NSPoint location = [(PBCommitList *)tv mouseDownPoint];
	NSInteger row = [tv rowAtPoint:location];
	NSInteger column = [tv columnAtPoint:location];

	PBGitRevisionCell *cell = (PBGitRevisionCell *)[tv viewAtColumn:column row:row makeIfNecessary:NO];
	PBGitCommit *commit = [[commitController arrangedObjects] objectAtIndex:row];

	int index = -1;
	if ([cell respondsToSelector:@selector(indexAtX:)]) {
		NSRect cellFrame = [tv frameOfCellAtColumn:column row:row];
		CGFloat deltaX = location.x - cellFrame.origin.x;
		index = [cell indexAtX:deltaX];
	}

	if (index != -1) {
		PBGitRef *ref = [[commit refs] objectAtIndex:index];
		if ([ref isTag] || [ref isRemoteBranch])
			return NO;

		if ([[[repository headRef] ref] isEqualToRef:ref])
			return NO;

		NSData *data = [NSKeyedArchiver archivedDataWithRootObject:[NSArray arrayWithObjects:[NSNumber numberWithInteger:row], [NSNumber numberWithInt:index], NULL]];
		[pboard declareTypes:[NSArray arrayWithObject:@"PBGitRef"] owner:self];
		[pboard setData:data forType:@"PBGitRef"];
	} else {
		[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];

		NSString *info = nil;
		if (column == [tv columnWithIdentifier:@"ShortSHAColumn"]) {
			info = [commit shortName];
		} else {
			info = [NSString stringWithFormat:@"%@ (%@)", [commit shortName], [commit subject]];
		}

		[pboard setString:info forType:NSStringPboardType];
	}

	return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tv
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)operation
{
	if (operation == NSTableViewDropAbove)
		return NSDragOperationNone;

	NSPasteboard *pboard = [info draggingPasteboard];
	if ([pboard dataForType:@"PBGitRef"])
		return NSDragOperationMove;

	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)operation
{
	if (operation != NSTableViewDropOn)
		return NO;

	NSPasteboard *pboard = [info draggingPasteboard];
	NSData *data = [pboard dataForType:@"PBGitRef"];
	if (!data)
		return NO;

	NSArray *numbers = [NSKeyedUnarchiver unarchiveObjectWithData:data];
	int oldRow = [[numbers objectAtIndex:0] intValue];
	if (oldRow == row)
		return NO;

	int oldRefIndex = [[numbers objectAtIndex:1] intValue];
	PBGitCommit *oldCommit = [[commitController arrangedObjects] objectAtIndex:oldRow];
	PBGitRef *ref = [[oldCommit refs] objectAtIndex:oldRefIndex];

	PBGitCommit *dropCommit = [[commitController arrangedObjects] objectAtIndex:row];

	NSString *subject = [dropCommit subject];
	if ([subject length] > 99)
		subject = [[subject substringToIndex:99] stringByAppendingString:@"…"];

	NSAlert *alert = [[NSAlert alloc] init];
	alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"Move %@: %@", @""), [ref refishType], [ref shortName]];
	alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"Move the %@ to point to the commit: %@", @""), [ref refishType], subject];

	[alert addButtonWithTitle:NSLocalizedString(@"Move", @"Move branch label - default button")];
	[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Move branch label - cancel button")];

	PBGitWindowController *wc = self.windowController;
	[wc confirmDialog:alert
suppressionIdentifier:kDialogAcceptDroppedRef
			forAction:^{
				NSError *error = nil;
				if (![wc.repository updateReference:ref toPointAtCommit:dropCommit error:&error]) {
					[wc showErrorSheet:error];
					return;
				}

				[dropCommit addRef:ref];
				[oldCommit removeRef:ref];
			}];

	return YES;
}


#pragma mark -
#pragma mark File browser

- (NSMenu *)contextMenuForTreeView
{
	NSArray *filePaths = [[treeController selectedObjects] valueForKey:@"fullPath"];

	NSMenu *menu = [[NSMenu alloc] init];
	for (NSMenuItem *item in [self menuItemsForPaths:filePaths])
		[menu addItem:item];
	return menu;
}

- (NSArray *)menuItemsForPaths:(NSArray *)paths
{
	NSMutableArray *filePaths = [NSMutableArray array];
	for (NSString *filePath in paths)
		[filePaths addObject:[filePath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];

	BOOL multiple = [filePaths count] != 1;
	NSString *historyItemTitle = multiple
		? NSLocalizedString(@"Show history of files", @"Show history menu item for multiple files")
		: NSLocalizedString(@"Show history of file", @"Show history menu item for single file");
	NSMenuItem *historyItem = [[NSMenuItem alloc] initWithTitle:historyItemTitle
														 action:@selector(showCommitsFromTree:)
												  keyEquivalent:@""];

	PBGitRef *headRef = [[repository headRef] ref];
	NSString *headRefName = [headRef shortName];
	NSString *diffTitleFormat = multiple
		? NSLocalizedString(@"Diff files with %@", @"Diff with ref menu item for multiple files")
		: NSLocalizedString(@"Diff file with %@", @"Diff with ref menu item for single file");
	NSString *diffTitle = [NSString stringWithFormat:diffTitleFormat, headRefName];
	BOOL isHead = [self.selectedCommits.firstObject.OID isEqual:repository.headOID];
	NSMenuItem *diffItem = [[NSMenuItem alloc] initWithTitle:diffTitle
													  action:isHead ? nil : @selector(diffFilesAction:)
											   keyEquivalent:@""];

	NSString *checkoutItemTitle = multiple
		? NSLocalizedString(@"Checkout files", @"Checkout menu item for multiple files")
		: NSLocalizedString(@"Checkout file", @"Checkout menu item for single file");
	NSMenuItem *checkoutItem = [[NSMenuItem alloc] initWithTitle:checkoutItemTitle
														  action:@selector(checkoutFiles:)
												   keyEquivalent:@""];
	
	NSString *finderItemTitle = NSLocalizedString(@"Reveal in Finder", @"Show in Finder menu item");
	NSMenuItem *finderItem = [[NSMenuItem alloc] initWithTitle:finderItemTitle
														action:@selector(revealInFinder:)
												 keyEquivalent:@""];
	
	NSString *openFilesItemTitle = multiple
		? NSLocalizedString(@"Open Files", @"Open menu item for multiple files")
		: NSLocalizedString(@"Open File", @"Open menu item for single file");
	NSMenuItem *openFilesItem = [[NSMenuItem alloc] initWithTitle:openFilesItemTitle
														   action:@selector(openFiles:)
													keyEquivalent:@""];

	NSArray *menuItems = [NSArray arrayWithObjects:historyItem, diffItem, checkoutItem, finderItem, openFilesItem, nil];
	for (NSMenuItem *item in menuItems) {
		[item setRepresentedObject:filePaths];
	}

	return menuItems;
}

#pragma mark -
#pragma mark Quick Look

#pragma mark <QLPreviewPanelDataSource>

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(id)panel
{
    return [[fileBrowser selectedRowIndexes] count];
}

- (id <QLPreviewItem>)previewPanel:(id)panel previewItemAtIndex:(NSInteger)index
{
	PBGitTree *treeItem = (PBGitTree *)[[treeController selectedObjects] objectAtIndex:index];
	NSURL *previewURL = [NSURL fileURLWithPath:[treeItem tmpFileNameForContents]];

    return (id <QLPreviewItem>)previewURL;
}

#pragma mark <QLPreviewPanelDelegate>

- (BOOL)previewPanel:(id)panel handleEvent:(NSEvent *)event
{
    // redirect all key down events to the table view
    if ([event type] == NSKeyDown) {
        [fileBrowser keyDown:event];
        return YES;
    }
    return NO;
}

// This delegate method provides the rect on screen from which the panel will zoom.
- (NSRect)previewPanel:(id)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item
{
    NSInteger index = [fileBrowser rowForItem:[[treeController selectedNodes] objectAtIndex:0]];
    if (index == NSNotFound) {
        return NSZeroRect;
    }

    NSRect iconRect = [fileBrowser frameOfCellAtColumn:0 row:index];

    // check that the icon rect is visible on screen
    NSRect visibleRect = [fileBrowser visibleRect];

    if (!NSIntersectsRect(visibleRect, iconRect)) {
        return NSZeroRect;
    }

    // convert icon rect to screen coordinates
	iconRect = [fileBrowser.window.contentView convertRect:iconRect fromView:fileBrowser];
	iconRect = [fileBrowser.window convertRectToScreen:iconRect];

    return iconRect;
}

@end

/*
 * TODO: This is kept for simplicity reasons. A "more correct" way of handling
 * menus would be to have them in NIBs, and handle them using NSMenuValidation.
 */

@implementation NSMenuItem (PBRefMenuItem)

+ (NSMenuItem *)pb_itemWithTitle:(NSString *)title action:(SEL)selector enabled:(BOOL)isEnabled
{
	if (!isEnabled)
		selector = nil;

	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:selector keyEquivalent:@""];
	[item setEnabled:isEnabled];
	return item;
}

@end

@implementation PBGitHistoryController (PBContextMenu)

- (NSArray<NSMenuItem *> *)menuItemsForStashRef:(PBGitRef *)ref
{
	NSMutableArray *items = [NSMutableArray array];
	NSString *targetRefName = [ref shortName];
	BOOL isCleanWorkingCopy = YES;

	// pop
	NSString *stashPopTitle = [NSString stringWithFormat:NSLocalizedString(@"Pop %@", @"Contextual Menu Item to pop the selected stash ref"), targetRefName];
	[items addObject:[NSMenuItem pb_itemWithTitle:stashPopTitle action:@selector(stashPop:) enabled:isCleanWorkingCopy]];

	// apply
	NSString *stashApplyTitle = [NSString stringWithFormat:NSLocalizedString(@"Apply %@", @"Contextual Menu Item to apply the selected stash ref"), targetRefName];
	[items addObject:[NSMenuItem pb_itemWithTitle:stashApplyTitle action:@selector(stashApply:) enabled:YES]];

	// view diff
	NSString *stashDiffTitle = @"View Diff";
	[items addObject:[NSMenuItem pb_itemWithTitle:stashDiffTitle action:@selector(stashViewDiff:) enabled:YES]];

	[items addObject:[NSMenuItem separatorItem]];

	// drop
	NSString *stashDropTitle = [NSString stringWithFormat:NSLocalizedString(@"Drop %@", @"Contextual Menu Item to drop the selected stash ref"), targetRefName];
	[items addObject:[NSMenuItem pb_itemWithTitle:stashDropTitle action:@selector(stashDrop:) enabled:YES]];

	for (NSMenuItem *item in items) {
		if (!item.representedObject) {
			item.representedObject = ref;
		}
	}

	return items;
}

- (NSArray<NSMenuItem *> *)menuItemsForRef:(PBGitRef *)ref
{
	if (!ref) {
		return nil;
	}

	/* FIXME: this is a workaround so we don't show a non-working menu when
	 * right-clicking the "actual" stash ref
	 */
	if ([ref.refishName isEqualToString:@"refs/stash"]) {
		return @[];
	}
	if (ref.isStash) {
		return [self menuItemsForStashRef:ref];
	}

	NSString *refName = ref.shortName;

	PBGitRef *headRef = self.repository.headRef.ref;
	NSString *headRefName = headRef.shortName;

	BOOL isHead = [ref isEqualToRef:headRef];
	BOOL isOnHeadBranch = isHead ? YES : [self.repository isRefOnHeadBranch:ref];
	BOOL isDetachedHead = (isHead && [headRefName isEqualToString:@"HEAD"]);

	NSString *remoteName = ref.remoteName;
	if (!remoteName && ref.isBranch) {
		remoteName = [[self.repository remoteRefForBranch:ref error:NULL] remoteName];
	}
	BOOL hasRemote = (remoteName ? YES : NO);
	BOOL isRemote = (ref.isRemote && !ref.isRemoteBranch);

	NSMutableArray *items = [NSMutableArray array];
	if (!isRemote) {
		// checkout ref
		NSString *checkoutTitle = [NSString stringWithFormat:NSLocalizedString(@"Checkout “%@”", @"Contextual Menu Item to check out the selected ref"), refName];
		[items addObject:[NSMenuItem pb_itemWithTitle:checkoutTitle action:@selector(checkout:) enabled:!isHead]];
		[items addObject:[NSMenuItem separatorItem]];

		// create branch
		NSString *createBranchTitle = ref.isRemoteBranch
		? [NSString stringWithFormat:NSLocalizedString(@"Create Branch tracking “%@”…", @"Contextual Menu Item to create a branch tracking the selected remote branch"), refName]
		: NSLocalizedString(@"Create Branch…", @"Contextual Menu Item to create a new branch at the selected ref");
		[items addObject:[NSMenuItem pb_itemWithTitle:createBranchTitle action:@selector(createBranch:) enabled:YES]];

		// create tag
		[items addObject:[NSMenuItem pb_itemWithTitle:NSLocalizedString(@"Create Tag…", @"Contextual Menu Item to create a tag at the selected ref") action:@selector(createTag:) enabled:YES]];

		// view tag info
		if (ref.isTag) {
			[items addObject:[NSMenuItem pb_itemWithTitle:NSLocalizedString(@"View Tag Info…", @"Contextual Menu Item to view Information about the selected tag") action:@selector(showTagInfoSheet:) enabled:YES]];
		}

		// Diff
		NSString *diffTitle = [NSString stringWithFormat:NSLocalizedString(@"Diff with “%@”", @"Contextual Menu Item to view a diff between the selected ref and HEAD"), headRefName];
		[items addObject:[NSMenuItem pb_itemWithTitle:diffTitle action:@selector(diffWithHEAD:) enabled:!isHead]];
		[items addObject:[NSMenuItem separatorItem]];

		// merge ref
		NSString *mergeTitle = isOnHeadBranch
		? NSLocalizedString(@"Merge", @"Inactive Contextual Menu Item for merging")
		: [NSString stringWithFormat:@"Merge %@ into %@", refName, headRefName];
		[items addObject:[NSMenuItem pb_itemWithTitle:mergeTitle action:@selector(merge:) enabled:!isOnHeadBranch]];

		// rebase
		NSString *rebaseTitle = isOnHeadBranch
		? NSLocalizedString(@"Rebase", @"Inactive Contextual Menu Item for rebasing")
		: [NSString stringWithFormat:NSLocalizedString(@"Rebase ”%@“ onto “%@”", @"Contextual Menu Item to rebase HEAD onto the selected ref"), headRefName, refName];
		[items addObject:[NSMenuItem pb_itemWithTitle:rebaseTitle action:@selector(rebaseHeadBranch:) enabled:!isOnHeadBranch]];

		[items addObject:[NSMenuItem separatorItem]];

		// reset
		NSString *resetTitle = [NSString stringWithFormat:NSLocalizedString(@"Reset to “%@”", @"Contextual Menu Item to reset to the selected ref"), refName];
		[items addObject:[NSMenuItem pb_itemWithTitle:resetTitle action:@selector(resetSoft:) enabled:!isHead]];

		[items addObject:[NSMenuItem separatorItem]];
	}

	// fetch
	NSString *fetchTitle = hasRemote
	? [NSString stringWithFormat:NSLocalizedString(@"Fetch “%@”", @"Contextual Menu Item to fetch the selected remote"), remoteName]
	: NSLocalizedString(@"Fetch", @"Inactive Contextual Menu Item for fetching");
	[items addObject:[NSMenuItem pb_itemWithTitle:fetchTitle action:@selector(fetchRemote:) enabled:hasRemote]];

	// pull
	NSString *pullTitle = hasRemote
	? [NSString stringWithFormat:NSLocalizedString(@"Pull “%@” and Update “%@”", @"Contextual Menu Item to pull the remote and update the selected branch"), remoteName, headRefName]
	: NSLocalizedString(@"Pull", @"Inactive Contextual Menu Item for pulling");
	[items addObject:[NSMenuItem pb_itemWithTitle:pullTitle action:@selector(pullRemote:) enabled:hasRemote]];

	// push
	if (isRemote || ref.isRemoteBranch) {
		// push updates to remote
		NSString *pushTitle = [NSString stringWithFormat:NSLocalizedString(@"Push Updates to “%@”", @"Contextual Menu Item to push updates of the selected ref to he named remote"), remoteName];
		[items addObject:[NSMenuItem pb_itemWithTitle:pushTitle action:@selector(pushUpdatesToRemote:) enabled:YES]];
	}
	else if (isDetachedHead) {
		[items addObject:[NSMenuItem pb_itemWithTitle:NSLocalizedString(@"Push", @"Inactive Contextual Menu Item for pushing") action:nil enabled:NO]];
	}
	else {
		// push to default remote
		BOOL hasDefaultRemote = NO;
		if (!ref.isTag && hasRemote) {
			hasDefaultRemote = YES;
			NSString *pushTitle = [NSString stringWithFormat:NSLocalizedString(@"Push “%@” to “%@”", @"Contextual Menu Item to push a ref to a specific remote"), refName, remoteName];
			[items addObject:[NSMenuItem pb_itemWithTitle:pushTitle action:@selector(pushDefaultRemoteForRef:) enabled:YES]];
		}

		// push to remotes submenu
		NSArray *remoteNames = [self.repository remotes];
		if ([remoteNames count] && !(hasDefaultRemote && ([remoteNames count] == 1))) {
			NSString *pushToTitle = [NSString stringWithFormat:NSLocalizedString(@"Push “%@” to", @"Contextual Menu Submenu Item containing the remotes the selected ref can be pushed to"), refName];
			NSMenuItem *pushToItem = [NSMenuItem pb_itemWithTitle:pushToTitle action:nil enabled:YES];
			NSMenu *remotesMenu = [[NSMenu alloc] initWithTitle:NSLocalizedString(@"Remotes Menu", @"Menu listing the repository’s remotes")];
			for (NSString *remote in remoteNames) {
				NSMenuItem *remoteItem = [NSMenuItem pb_itemWithTitle:remote action:@selector(pushToRemote:) enabled:YES];
				remoteItem.representedObject = remote;
				[remotesMenu addItem:remoteItem];
			}
			[pushToItem setSubmenu:remotesMenu];
			pushToItem.representedObject = ref;
			[items addObject:pushToItem];
		}
	}

	// delete ref
	[items addObject:[NSMenuItem separatorItem]];
	BOOL isStash = [[ref ref] hasPrefix:@"refs/stash"];
	BOOL isDeleteEnabled = !(isDetachedHead || isHead || isStash);
	if (isDeleteEnabled) {
		NSString *deleteFormat = ref.isRemote
		? NSLocalizedString(@"Delete “%@”…", @"Contextual Menu Item to delete a local ref (e.g. branch)")
		: NSLocalizedString(@"Remove “%@”…", @"Contextual Menu Item to remove a remote");
		NSString *deleteItemTitle = [NSString stringWithFormat:deleteFormat, refName];
		NSMenuItem *deleteItem = [NSMenuItem pb_itemWithTitle:deleteItemTitle action:@selector(deleteRef:) enabled:YES];
		[items addObject:deleteItem];
	}

	for (NSMenuItem *item in items) {
		if (!item.representedObject) {
			item.representedObject = ref;
		}
	}

	return items;
}

- (NSArray<NSMenuItem *> *)menuItemsForCommits:(NSArray<PBGitCommit *> *)commits
{
	NSMutableArray *items = [NSMutableArray array];

	BOOL isSingleCommitSelection = commits.count == 1;
	PBGitCommit *firstCommit = commits.firstObject;

	NSString *headBranchName = firstCommit.repository.headRef.ref.shortName;
	BOOL isOnHeadBranch = firstCommit.isOnHeadBranch;
	BOOL isHead = [firstCommit.OID isEqual:firstCommit.repository.headOID];

	if (isSingleCommitSelection) {
		[items addObject:[NSMenuItem pb_itemWithTitle:NSLocalizedString(@"Checkout Commit", @"Contextual Menu Item to check out the selected commit") action:@selector(checkout:) enabled:YES]];
		[items addObject:[NSMenuItem separatorItem]];

		[items addObject:[NSMenuItem pb_itemWithTitle:NSLocalizedString(@"Create Branch…", @"Contextual Menu Item to create a branch at the selected commit") action:@selector(createBranch:) enabled:YES]];
		[items addObject:[NSMenuItem pb_itemWithTitle:NSLocalizedString(@"Create Tag…", @"Contextual Menu Item to create a tag at the selected commit") action:@selector(createTag:) enabled:YES]];
		[items addObject:[NSMenuItem separatorItem]];
	}

	[items addObject:[NSMenuItem pb_itemWithTitle:NSLocalizedString(@"Copy SHA", @"Contextual Menu Item to copy the selected commits’ full SHA(s)") action:@selector(copySHA:) enabled:YES]];
	[items addObject:[NSMenuItem pb_itemWithTitle:NSLocalizedString(@"Copy short SHA", @"Contextual Menu Item to copy the selected commits’ short SHA(s)") action:@selector(copyShortName:) enabled:YES]];
	[items addObject:[NSMenuItem pb_itemWithTitle:NSLocalizedString(@"Copy Patch", @"Contextual Menu Item to copy the selected commits as patch(es)") action:@selector(copyPatch:) enabled:YES]];

	if (isSingleCommitSelection) {
		NSString *diffTitle = [NSString stringWithFormat:NSLocalizedString(@"Diff with “%@”", @"Contextual Menu Item to view a diff between the selected commit and HEAD"), headBranchName];
		[items addObject:[NSMenuItem pb_itemWithTitle:diffTitle action:@selector(diffWithHEAD:) enabled:!isHead]];
		[items addObject:[NSMenuItem separatorItem]];

		// merge commit
		NSString *mergeTitle = isOnHeadBranch
		? NSLocalizedString(@"Merge Commit", @"Inactive Contextual Menu Item for merging commits")
		: [NSString stringWithFormat:NSLocalizedString(@"Merge Commit into “%@”", @"Contextual Menu Item to merge the selected commit into HEAD"), headBranchName];
		[items addObject:[NSMenuItem pb_itemWithTitle:mergeTitle action:@selector(merge:) enabled:!isOnHeadBranch]];

		// cherry pick
		NSString *cherryPickTitle = isOnHeadBranch
		? NSLocalizedString(@"Cherry Pick Commit", @"Inactive Contextual Menu Item for cherry-picking commits")
		: [NSString stringWithFormat:NSLocalizedString(@"Cherry Pick Commit to “%@”", @"Contextual Menu Item to cherry-pick the selected commit on top of HEAD"), headBranchName];
		[items addObject:[NSMenuItem pb_itemWithTitle:cherryPickTitle action:@selector(cherryPick:) enabled:!isOnHeadBranch]];

		// rebase
		NSString *rebaseTitle = isOnHeadBranch
		? NSLocalizedString(@"Rebase Commit", @"Inactive Contextual Menu Item for rebasing onto commits")
		: [NSString stringWithFormat:NSLocalizedString(@"Rebase “%@” onto Commit", @"Contextual Menu Item to rebase the HEAD branch onto the selected commit"), headBranchName];
		[items addObject:[NSMenuItem pb_itemWithTitle:rebaseTitle action:@selector(rebaseHeadBranch:) enabled:!isOnHeadBranch]];

		// reset
		NSString *resetTitle = NSLocalizedString(@"Reset to commit", @"Contextual Menu Item to reset to the selected ref");
		[items addObject:[NSMenuItem pb_itemWithTitle:resetTitle action:@selector(resetSoft:) enabled:!isHead]];
	}

	for (NSMenuItem *item in items) {
		if (!item.representedObject) {
			item.representedObject = isSingleCommitSelection ? firstCommit : commits;
		}
	}

	return items;
}

@end

