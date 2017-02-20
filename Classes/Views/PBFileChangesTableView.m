//
//  PBFileChangesTableView.m
//  GitX
//
//  Created by Pieter de Bie on 09-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBFileChangesTableView.h"
#import "PBGitIndexController.h"
#import "PBChangedFile.h"

@interface PBFileChangesTableView()
- (PBGitIndexController *) delegate;
@end


@implementation PBFileChangesTableView

#pragma mark NSTableView overrides

- (PBGitIndexController *) delegate
{
	return (PBGitIndexController *)[super delegate];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if ([self delegate]) {
		NSPoint eventLocation = [self convertPoint: [theEvent locationInWindow] fromView: nil];
		NSInteger rowIndex = [self rowAtPoint:eventLocation];
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:YES];
		return [super menuForEvent:theEvent];
	}

	return nil;
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
	return NSDragOperationEvery;
}


#pragma mark Event Handling

- (BOOL) validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem.action == @selector(stageFilesAction:)) {
		menuItem.title = [self.class menuItemTitleForSelection:self.filesForStaging
									titleForMenuItemWithSingle:NSLocalizedString(@"Stage “%@”", @"Stage file menu item (single file with name)")
													  multiple:NSLocalizedString(@"Stage %i Files", @"Stage file menu item (multiple files with number)")
													   default:NSLocalizedString(@"Stage", @"Stage file menu item (empty selection)")];
		[self possiblySetHidden:!self.hasFilesForStaging forMenuItem:menuItem];
		return self.hasFilesForStaging;
	}
	else if (menuItem.action == @selector(unstageFilesAction:)) {
		menuItem.title = [self.class menuItemTitleForSelection:self.filesForUnstaging
									titleForMenuItemWithSingle:NSLocalizedString(@"Unstage “%@”", @"Unstage file menu item (single file with name)")
													  multiple:NSLocalizedString(@"Unstage %i Files", @"Unstage file menu item (multiple files with number)")
													   default:NSLocalizedString(@"Unstage", @"Unstage file menu item (empty selection)")];
		[self possiblySetHidden:!self.hasFilesForUnstaging forMenuItem:menuItem];
		return self.hasFilesForUnstaging;
	}
	else if (menuItem.action == @selector(discardFilesAction:)) {
		menuItem.title = [self.class menuItemTitleForSelection:self.filesForStaging
									titleForMenuItemWithSingle:NSLocalizedString(@"Discard changes to “%@”…", @"Discard changes menu item (single file with name)")
													  multiple:NSLocalizedString(@"Discard changes to  %i Files…", @"Discard changes menu item (multiple files with number)")
													   default:NSLocalizedString(@"Discard…", @"Discard changes menu item (empty selection)")];
		[self possiblySetHidden:self.shouldTrashInsteadOfDiscard forMenuItem:menuItem];
		return self.hasFilesForStaging && self.canDiscardAnyFile;
	}
	else if (menuItem.action == @selector(forceDiscardFilesAction:)) {
		menuItem.title = [self.class menuItemTitleForSelection:self.filesForStaging
									titleForMenuItemWithSingle:NSLocalizedString(@"Discard changes to “%@”", @"Force Discard changes menu item (single file with name)")
													  multiple:NSLocalizedString(@"Discard changes to  %i Files", @"Force Discard changes menu item (multiple files with number)")
													   default:NSLocalizedString(@"Discard", @"Force Discard changes menu item (empty selection)")];
		BOOL shouldHide = self.shouldTrashInsteadOfDiscard;
		[self possiblySetHidden:shouldHide forMenuItem:menuItem];
		// NSMenu does not seem to hide alternative items properly: only activate the alternative seeing when menu item is shown.
		menuItem.alternate = !shouldHide;
		return self.hasFilesForStaging && self.canDiscardAnyFile;
	}
	else if (menuItem.action == @selector(trashFilesAction:)) {
		menuItem.title = [self.class menuItemTitleForSelection:self.filesForStaging
									titleForMenuItemWithSingle:NSLocalizedString(@"Move “%@” to Trash", @"Move to Trash menu item (single file with name)")
													  multiple:NSLocalizedString(@"Move %i Files to Trash", @"Move to Trash menu item (multiple files with number)")
													   default:NSLocalizedString(@"Move to Trash", @"Move to Trash menu item (empty selection)")];
		BOOL isVisible = self.shouldTrashInsteadOfDiscard && self.tag != 1;
		[self possiblySetHidden:!isVisible forMenuItem:menuItem];
		return self.hasFilesForStaging && self.canDiscardAnyFile;
	}
	else if (menuItem.action == @selector(openFilesAction:)) {
		NSArray<PBChangedFile *> *selectedFiles = self.selectedFilesInThisTable;
		if (selectedFiles.count > 0) {
			NSString *filePath = selectedFiles.firstObject.path;
			if (selectedFiles.count == 1 && [self.indexController submoduleAtPath:filePath] != nil) {
				menuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Open Submodule “%@” in GitX", @"Open Submodule Repository in GitX menu item (single file with name)"),
								  filePath.stringByStandardizingPath];
			} else {
				menuItem.title = [self.class menuItemTitleForSelection:self.selectedFilesInThisTable
											titleForMenuItemWithSingle:NSLocalizedString(@"Open “%@”", @"Open File menu item (single file with name)")
															  multiple:NSLocalizedString(@"Open %i Files", @"Open File menu item (multiple files with number)")
															   default:NSLocalizedString(@"Open", @"Open File menu item (empty selection)")];
			}
			return YES;
		}
		return NO;
	}
	else if (menuItem.action == @selector(ignoreFilesAction:)) {
		menuItem.title = [self.class menuItemTitleForSelection:self.selectedFilesInThisTable
									titleForMenuItemWithSingle:NSLocalizedString(@"Ignore “%@”", @"Ignore File menu item (single file with name)")
													  multiple:NSLocalizedString(@"Ignore %i Files", @"Ignore File menu item (multiple files with number)")
													   default:NSLocalizedString(@"Ignore", @"Ignore File menu item (empty selection)")];
		BOOL isActive = self.hasSelectedFilesInThisTable && self.tag == 0;
		[self possiblySetHidden:!isActive forMenuItem:menuItem];
		return isActive;
	}
	else if (menuItem.action == @selector(showInFinderAction:)) {
		BOOL active = NO;
		NSArray<PBChangedFile *> *selectedFiles = self.selectedFilesInThisTable;
		if (selectedFiles.count == 1) {
			menuItem.title = [NSString stringWithFormat:NSLocalizedString(@"Reveal “%@” in Finder", @"Reveal File in Finder menu item (single file with name)"),
							  [PBGitIndexController getNameOfFirstFile:selectedFiles]];
			active = YES;
		} else {
			menuItem.title = NSLocalizedString(@"Reveal in Finder", @"Reveal File in Finder menu item (empty selection)");
		}
		[self possiblySetHidden:!active forMenuItem:menuItem];
		return active;
	}

	return [super validateMenuItem:menuItem];
}

/**
 * Method only hiding the menu item when we are in the contextual menu.
 */
- (void) possiblySetHidden:(BOOL)hidden forMenuItem:(NSMenuItem *)menuItem {
	BOOL isInContextualMenu = menuItem.parentItem == nil;
	if (isInContextualMenu) {
		menuItem.hidden = hidden;
	}
}


+ (NSString *) menuItemTitleForSelection:(NSArray<PBChangedFile *> *)files
			  titleForMenuItemWithSingle:(NSString *)singleFormat
								multiple:(NSString *)multipleFormat
								 default:(NSString *)defaultString {
	
	NSUInteger numberOfFiles = files.count;
	
	if (numberOfFiles == 0) {
		return defaultString;
	}
	else if (numberOfFiles == 1) {
		return [NSString stringWithFormat:singleFormat, [PBGitIndexController getNameOfFirstFile:files]];
	}
	return [NSString stringWithFormat:multipleFormat, numberOfFiles];
}

- (BOOL) hasFilesForStaging {
	return self.numberOfSelectedFilesForStaging > 0;
}

- (NSUInteger) numberOfSelectedFilesForStaging{
	return self.filesForStaging.count;
}

- (NSArray<PBChangedFile *> *) filesForStaging {
	return [self delegate].unstagedFilesController.selectedObjects;
}

- (BOOL) hasFilesForUnstaging {
	return self.numberOfSelectedFilesForUnstaging > 0;
}

- (NSUInteger) numberOfSelectedFilesForUnstaging{
	return self.filesForUnstaging.count;
}

- (NSArray<PBChangedFile *> *) filesForUnstaging {
	return [self delegate].stagedFilesController.selectedObjects;
}

- (BOOL) hasSelectedFilesInThisTable {
	return self.numberOfSelectedFilesInThisTable > 0;
}

- (NSUInteger) numberOfSelectedFilesInThisTable {
	return self.selectedFilesInThisTable.count;
}

- (NSArray<PBChangedFile *> *) selectedFilesInThisTable {
	NSArrayController * relevantController = self.tag == 0 ? [self delegate].unstagedFilesController : [self delegate].stagedFilesController;
	return relevantController.selectedObjects;
}



- (BOOL) canDiscardAnyFile {
	return [PBGitIndexController canDiscardAnyFileIn:self.filesForStaging];
}

- (BOOL) shouldTrashInsteadOfDiscard {
	return [PBGitIndexController shouldTrashInsteadOfDiscardAnyFileIn:self.filesForStaging];
}



#pragma mark IBActions

- (IBAction) stageFilesAction:(id)sender
{
	[[self delegate] stageSelectedFiles];
}

- (IBAction) unstageFilesAction:(id)sender
{
	[[self delegate] unstageSelectedFiles];
}

- (IBAction) discardFilesAction:(id)sender
{
	[self discardFiles:sender force:NO];
}

- (IBAction) forceDiscardFilesAction:(id)sender
{
	[self discardFiles:sender force:YES];
}

- (void) discardFiles:(id)sender force:(BOOL)force
{
	NSArray<PBChangedFile *> *selectedFiles = self.selectedFilesInThisTable;
	if (selectedFiles.count > 0) {
		[[self delegate] discardChangesForFiles:selectedFiles force:force];
	}
}

- (IBAction) trashFilesAction:(id)sender
{
	[[self delegate] moveToTrash:self.selectedFilesInThisTable];
}

- (IBAction) openFilesAction:(id)sender
{
	[[self delegate] openFilesAction:self.selectedFilesInThisTable];
}

- (IBAction) ignoreFilesAction:(id)sender
{
	[[self delegate] ignoreFilesAction:self.selectedFilesInThisTable];
}

- (IBAction) showInFinderAction:(id)sender
{
	[[self delegate] showInFinderAction:self.selectedFilesInThisTable];
}


#pragma mark NSView overrides

-(BOOL)acceptsFirstResponder
{
    return [self numberOfRows] > 0;
}

-(NSView *)nextKeyView
{
    return [[self delegate] nextKeyViewFor:self];
}

-(NSView *)previousKeyView
{
    return [[self delegate] previousKeyViewFor:self];
}

@end
