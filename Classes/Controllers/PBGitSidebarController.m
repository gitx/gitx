//
//  PBGitSidebar.m
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PBGitSidebarController.h"
#import "PBSourceViewItems.h"
#import "PBGitHistoryController.h"
#import "PBGitCommitController.h"
#import "NSOutlineViewExt.h"
#import "PBAddRemoteSheet.h"
#import "PBGitDefaults.h"
#import "PBHistorySearchController.h"
#import "PBGitStash.h"
#import "PBSourceViewGitStashItem.h"
#import "PBSidebarTableViewCell.h"
#import "PBGitRef.h"

#define PBSidebarCellIdentifier @"PBSidebarCellIdentifier"

@interface PBGitSidebarController () <NSOutlineViewDelegate> {
	__weak IBOutlet NSWindow *window;
	__weak IBOutlet NSOutlineView *sourceView;
	__weak IBOutlet NSView *sourceListControlsView;
	__weak IBOutlet NSPopUpButton *actionButton;
	__weak IBOutlet NSSegmentedControl *remoteControls;

	NSMutableArray *items;

	/* Specific things */
	PBSourceViewItem *stage;

	PBSourceViewItem *branches, *remotes, *tags, *others, *submodules, *stashes;
}

- (void)populateList;
- (PBSourceViewItem *)addRevSpec:(PBGitRevSpecifier *)revSpec;
- (PBSourceViewItem *)itemForRev:(PBGitRevSpecifier *)rev;
- (void)removeRevSpec:(PBGitRevSpecifier *)rev;
- (void)updateActionMenu;
- (void)updateRemoteControls;
@end

@implementation PBGitSidebarController
@synthesize items;
@synthesize remotes;
@synthesize sourceView;
@synthesize sourceListControlsView;

- (instancetype)initWithRepository:(PBGitRepository *)theRepository superController:(PBGitWindowController *)controller
{
	self = [super initWithRepository:theRepository superController:controller];
	if (!self) return nil;

	[sourceView setDelegate:self];
	items = [NSMutableArray array];

	return self;
}

- (void)awakeFromNib
{
	[super awakeFromNib];
	window.contentView = self.view;
	[self populateList];

	PBGitRepository *repository = self.repository;

	[repository addObserver:self
					keyPath:@"currentBranch"
					options:0
					  block:^(MAKVONotification *notification) {
						  PBGitSidebarController *observer = notification.observer;
						  NSInteger row = observer.sourceView.selectedRow;
						  [observer.sourceView reloadData];
						  [observer.sourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
						  [observer selectCurrentBranch];
					  }];

	[repository addObserver:self
					keyPath:@"branches"
					options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
					  block:^(MAKVONotification *notification) {
						  PBGitSidebarController *observer = notification.observer;
						  if (notification.kind == NSKeyValueChangeInsertion) {
							  NSArray *newRevSpecs = notification.newValue;
							  for (PBGitRevSpecifier *rev in newRevSpecs) {
								  PBSourceViewItem *item = [observer addRevSpec:rev];
								  [observer.sourceView PBExpandItem:item expandParents:YES];
							  }
						  } else if (notification.kind == NSKeyValueChangeRemoval) {
							  NSArray *removedRevSpecs = notification.oldValue;
							  for (PBGitRevSpecifier *rev in removedRevSpecs)
								  [observer removeRevSpec:rev];
						  }
					  }];

	[repository addObserver:self
					keyPath:@"stashes"
					options:0
					  block:^(MAKVONotification *notification) {
						  PBGitSidebarController *observer = notification.observer;
						  for (PBSourceViewGitStashItem *stashItem in observer->stashes.sortedChildren)
							  [observer->stashes removeChild:stashItem];

						  for (PBGitStash *stash in observer.repository.stashes)
							  [observer->stashes addChild:[PBSourceViewGitStashItem itemWithStash:stash]];

						  [observer.sourceView expandItem:observer->stashes];
						  [observer.sourceView reloadItem:observer->stashes reloadChildren:YES];
					  }];

	[sourceView setTarget:self];
	[sourceView setDoubleAction:@selector(doubleClicked:)];

	[self menuNeedsUpdate:[actionButton menu]];

	if ([PBGitDefaults showStageView])
		[self selectStage];
	else
		[self selectCurrentBranch];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(expandCollapseItem:) name:NSOutlineViewItemWillExpandNotification object:sourceView];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(expandCollapseItem:) name:NSOutlineViewItemWillCollapseNotification object:sourceView];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSOutlineViewItemWillExpandNotification object:sourceView];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSOutlineViewItemWillCollapseNotification object:sourceView];
}

- (PBSourceViewItem *)selectedItem
{
	NSInteger index = [sourceView selectedRow];
	PBSourceViewItem *item = [sourceView itemAtRow:index];

	return item;
}

- (void)selectStage
{
	NSIndexSet *index = [NSIndexSet indexSetWithIndex:[sourceView rowForItem:stage]];
	[sourceView selectRowIndexes:index byExtendingSelection:NO];
}

- (void)selectCurrentBranch
{
	PBGitRepository *repository = self.repository;
	PBGitRevSpecifier *rev = repository.currentBranch;
	if (!rev) {
		[repository reloadRefs];
		[repository readCurrentBranch];
		return;
	}

	if (@available(macOS 10.12, *))
		dispatch_assert_queue(dispatch_get_main_queue());

	PBSourceViewItem *item = [self addRevSpec:rev];
	if (item) {
		[sourceView PBExpandItem:item expandParents:YES];
		NSIndexSet *index = [NSIndexSet indexSetWithIndex:[sourceView rowForItem:item]];

		[sourceView deselectAll:nil];
		[sourceView selectRowIndexes:index byExtendingSelection:NO];
	}
}

- (PBSourceViewItem *)itemForRev:(PBGitRevSpecifier *)rev
{
	PBSourceViewItem *foundItem = nil;
	for (PBSourceViewItem *item in items)
		if ((foundItem = [item findRev:rev]) != nil)
			return foundItem;
	return nil;
}

- (PBSourceViewItem *)addRevSpec:(PBGitRevSpecifier *)rev
{
	PBSourceViewItem *item = nil;
	for (PBSourceViewItem *it in items)
		if ((item = [it findRev:rev]) != nil)
			return item;

	if (![rev isSimpleRef]) {
		[others addChild:[PBSourceViewItem itemWithRevSpec:rev]];
		return item;
	}

	NSArray *pathComponents = [[rev simpleRef] componentsSeparatedByString:@"/"];
	if ([pathComponents count] < 2)
		[branches addChild:[PBSourceViewItem itemWithRevSpec:rev]];
	else if ([[pathComponents objectAtIndex:1] isEqualToString:@"heads"])
		[branches addRev:rev toPath:[pathComponents subarrayWithRange:NSMakeRange(2, [pathComponents count] - 2)]];
	else if ([[rev simpleRef] hasPrefix:@"refs/tags/"])
		[tags addRev:rev toPath:[pathComponents subarrayWithRange:NSMakeRange(2, [pathComponents count] - 2)]];
	else if ([[rev simpleRef] hasPrefix:@"refs/remotes/"])
		[remotes addRev:rev toPath:[pathComponents subarrayWithRange:NSMakeRange(2, [pathComponents count] - 2)]];
	return item;
}

- (void)removeRevSpec:(PBGitRevSpecifier *)rev
{
	PBSourceViewItem *item = [self itemForRev:rev];

	if (!item)
		return;

	PBSourceViewItem *parent = item.parent;
	[parent removeChild:item];
	[sourceView reloadData];
}

- (void)openSubmoduleFromMenuItem:(NSMenuItem *)menuItem
{
	[self openSubmoduleAtURL:[menuItem representedObject]];
}

- (void)openSubmoduleAtURL:(NSURL *)submoduleURL
{
  NSWindow *currentWindow = [[NSApplication sharedApplication] keyWindow];
  NSEvent *theEvent = [[NSApplication sharedApplication] currentEvent];
  BOOL openInTab = (theEvent && [theEvent modifierFlags] & NSEventModifierFlagOption)!=0;
  [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:submoduleURL
                                                   display:YES
                                                   completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {

    if (error) {
      [self.windowController showErrorSheet:error];
    }
    else if (!documentWasAlreadyOpen) {
      if (@available(macOS 10.13, *)) {
        if (openInTab) {
          // move into a tab of the original window
          if (currentWindow) {
            NSWindow *myWindow = [[document.windowControllers firstObject] window];
            if (myWindow) {
              NSWindowTabGroup *tabGroup = currentWindow.tabGroup;
              [tabGroup addWindow:myWindow];
            }
          }
        }
      }
    }
  }];
}

#pragma mark NSOutlineView delegate methods

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSInteger index = [sourceView selectedRow];
	PBSourceViewItem *item = [sourceView itemAtRow:index];
	PBGitWindowController *windowController = self.windowController;

	if ([item revSpecifier]) {
		if (![self.repository.currentBranch isEqual:[item revSpecifier]]) {
			self.repository.currentBranch = [item revSpecifier];
		}

		[windowController changeContentController:windowController.historyViewController];
		[PBGitDefaults setShowStageView:NO];
	}

	if (item == stage) {
		[windowController changeContentController:windowController.commitViewController];
		[PBGitDefaults setShowStageView:YES];
	}

	[self updateActionMenu];
	[self updateRemoteControls];
}

- (void)doubleClicked:(id)object
{
	NSInteger rowNumber = [sourceView selectedRow];

	id item = [sourceView itemAtRow:rowNumber];
	if ([item isKindOfClass:[PBSourceViewGitSubmoduleItem class]]) {
		PBSourceViewGitSubmoduleItem *subModule = item;

		[self openSubmoduleAtURL:[subModule path]];
	} else if ([item isKindOfClass:[PBSourceViewGitBranchItem class]]) {
		PBSourceViewGitBranchItem *branch = item;

		NSError *error = nil;
		BOOL success = [self.repository checkoutRefish:[branch ref] error:&error];
		if (!success) {
			[self.windowController showErrorSheet:error];
		}
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if ([item isKindOfClass:[PBSourceViewGitSubmoduleItem class]]) {
		NSLog(@"hi");
	}
	return NO;
}
#pragma mark NSOutlineView delegate methods
- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
	return [item isGroupItem];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(PBSourceViewItem *)item
{
	PBSidebarTableViewCell *cell = [outlineView makeViewWithIdentifier:PBSidebarCellIdentifier owner:outlineView];

	cell.textField.stringValue = [[item title] copy];
	cell.imageView.image = item.icon;
	cell.isCheckedOut = [item.revSpecifier isEqual:[self.repository headRef]];

	return cell;
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
	NSTableRowView *view = [sourceView rowViewAtRow:[sourceView rowForItem:item] makeIfNecessary:NO];

	if (view) {
		return view;
	}

	return [NSTableRowView new];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return ![item isGroupItem];
}

//
// The next method is necessary to hide the triangle for uncollapsible items
// That is, items which should always be displayed, such as the Project group.
// This also moves the group item to the left edge.
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldShowOutlineCellForItem:(id)item
{
	return ![item isUncollapsible];
}

- (void)populateList
{
	PBGitRepository *repository = self.repository;
	PBSourceViewItem *project = [PBSourceViewItem groupItemWithTitle:[repository projectName]];
	project.uncollapsible = YES;

	stage = [PBSourceViewStageItem stageItem];
	[project addChild:stage];

	branches = [PBSourceViewItem groupItemWithTitle:@"Branches"];
	remotes = [PBSourceViewItem groupItemWithTitle:@"Remotes"];
	tags = [PBSourceViewItem groupItemWithTitle:@"Tags"];
	stashes = [PBSourceViewItem groupItemWithTitle:@"Stashes"];
	submodules = [PBSourceViewItem groupItemWithTitle:@"Submodules"];
	others = [PBSourceViewItem groupItemWithTitle:@"Other"];

	for (PBGitStash *stash in repository.stashes)
		[stashes addChild:[PBSourceViewGitStashItem itemWithStash:stash]];

	for (PBGitRevSpecifier *rev in repository.branches) {
		[self addRevSpec:rev];
	}

	for (GTSubmodule *sub in repository.submodules) {
		[submodules addChild:[PBSourceViewGitSubmoduleItem itemWithSubmodule:sub]];
	}

	[items addObject:project];
	[items addObject:branches];
	[items addObject:remotes];
	[items addObject:tags];
	[items addObject:stashes];
	[items addObject:submodules];
	[items addObject:others];

	[sourceView reloadData];
	[sourceView expandItem:project];
	[sourceView expandItem:branches expandChildren:YES];
	[sourceView expandItem:remotes];
	[sourceView expandItem:stashes];
	[sourceView expandItem:submodules];

	[sourceView reloadItem:nil reloadChildren:YES];
}

- (void)expandCollapseItem:(NSNotification *)aNotification
{
	NSObject *child = [[aNotification userInfo] valueForKey:@"NSObject"];
	if ([child isKindOfClass:[PBSourceViewItem class]]) {
		((PBSourceViewItem *)child).expanded = [aNotification.name isEqualToString:NSOutlineViewItemWillExpandNotification];
	}
}

#pragma mark NSOutlineView Datasource methods

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if (!item)
		return [items objectAtIndex:index];

	return [[(PBSourceViewItem *)item sortedChildren] objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [[(PBSourceViewItem *)item sortedChildren] count] > 0;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (!item)
		return [items count];

	return [[(PBSourceViewItem *)item sortedChildren] count];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	return [(PBSourceViewItem *)item title];
}


#pragma mark Menus

- (void)updateActionMenu
{
	[actionButton setEnabled:([[self selectedItem] ref] != nil || [[self selectedItem] isKindOfClass:[PBSourceViewGitSubmoduleItem class]])];
}

- (void)addMenuItemsForRef:(PBGitRef *)ref toMenu:(NSMenu *)menu
{
	if (!ref)
		return;

	for (NSMenuItem *menuItem in [self.windowController.historyViewController menuItemsForRef:ref])
		[menu addItem:menuItem];
}

- (void)addMenuItemsForSubmodule:(PBSourceViewGitSubmoduleItem *)submodule toMenu:(NSMenu *)menu
{
	if (!submodule)
		return;

	NSMenuItem *menuItem = [menu addItemWithTitle:NSLocalizedString(@"Open Submodule", @"Open Submodule menu item") action:@selector(openSubmoduleFromMenuItem:) keyEquivalent:@""];

	[menuItem setTarget:self];
	[menuItem setRepresentedObject:[submodule path]];
}

- (NSMenuItem *)actionIconItem
{
	NSMenuItem *actionIconItem = [[NSMenuItem alloc] initWithTitle:@"" action:NULL keyEquivalent:@""];
	NSImage *actionIcon = [NSImage imageNamed:@"NSActionTemplate"];
	[actionIcon setSize:NSMakeSize(12, 12)];
	[actionIconItem setImage:actionIcon];

	return actionIconItem;
}

- (NSMenu *)menuForRow:(NSInteger)row
{
	PBSourceViewItem *viewItem = [sourceView itemAtRow:row];
	PBGitRef *ref = [viewItem ref];
	NSMenu *menu = [[NSMenu alloc] init];

	[menu setAutoenablesItems:NO];

	if (ref) {
		[self addMenuItemsForRef:ref toMenu:menu];
	}

	if ([viewItem isKindOfClass:[PBSourceViewGitSubmoduleItem class]]) {
		[self addMenuItemsForSubmodule:(PBSourceViewGitSubmoduleItem *)viewItem toMenu:menu];
	}

	return menu;
}

// delegate of the action menu
- (void)menuNeedsUpdate:(NSMenu *)menu
{
	[actionButton removeAllItems];
	[menu addItem:[self actionIconItem]];

	PBGitRef *ref = [[self selectedItem] ref];
	[self addMenuItemsForRef:ref toMenu:menu];

	if ([[self selectedItem] isKindOfClass:[PBSourceViewGitSubmoduleItem class]]) {
		[self addMenuItemsForSubmodule:(PBSourceViewGitSubmoduleItem *)[self selectedItem] toMenu:menu];
	}
}


#pragma mark Remote controls

enum {
	kAddRemoteSegment = 0,
	kFetchSegment = 1,
	kPullSegment = 2,
	kPushSegment = 3
};

- (void)updateRemoteControls
{
	BOOL hasRemote = NO;

	PBGitRef *ref = [[self selectedItem] ref];
	if ([ref isRemote] || ([ref isBranch] && [[self.repository remoteRefForBranch:ref error:NULL] remoteName]))
		hasRemote = YES;

	[remoteControls setEnabled:hasRemote forSegment:kFetchSegment];
	[remoteControls setEnabled:hasRemote forSegment:kPullSegment];
	[remoteControls setEnabled:hasRemote forSegment:kPushSegment];
}

- (IBAction)fetchPullPushAction:(id)sender
{
	NSInteger selectedSegment = [sender selectedSegment];

	if (selectedSegment == kAddRemoteSegment) {
		[self tryToPerform:@selector(addRemote:) with:self];
		return;
	}

	NSInteger index = [sourceView selectedRow];
	PBSourceViewItem *item = [sourceView itemAtRow:index];
	PBGitRef *ref = [[item revSpecifier] ref];

	if (!ref && (item.parent == remotes))
		ref = [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:[item title]]];

	if (![ref isRemote] && ![ref isBranch])
		return;

	PBGitRef *remoteRef = [self.repository remoteRefForBranch:ref error:NULL];
	if (!remoteRef)
		return;

	if (selectedSegment == kFetchSegment) {
		[self.windowController performFetchForRef:ref];
	} else if (selectedSegment == kPullSegment) {
		[self.windowController performPullForBranch:ref remote:remoteRef rebase:NO];
	} else if (selectedSegment == kPushSegment && ref.isRemote) {
		[self.windowController performPushForBranch:nil toRemote:remoteRef];
	} else if (selectedSegment == kPushSegment && ref.isBranch) {
		[self.windowController performPushForBranch:ref toRemote:remoteRef];
	}
}

@end
