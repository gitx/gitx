//
//  PBGitIndexController.m
//  GitX
//
//  Created by Pieter de Bie on 18-11-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBGitIndexController.h"
#import "PBChangedFile.h"
#import "PBGitRepository.h"
#import "PBGitIndex.h"
#import "PBOpenFiles.h"

#define FileChangesTableViewType @"GitFileChangedType"

@interface PBGitIndexController ()
- (void)discardChangesForFiles:(NSArray<PBChangedFile *> *)files force:(BOOL)force;
@end

// FIXME: This isn't a view/window/whatever controller, though it acts like one...
// See for example -menuForTable and its setTarget: calls.
@implementation PBGitIndexController

@synthesize stagedFilesController, unstagedFilesController, stagedTable, unstagedTable;

- (void)awakeFromNib
{
	[unstagedTable setDoubleAction:@selector(tableClicked:)];
	[stagedTable setDoubleAction:@selector(tableClicked:)];

	[unstagedTable setTarget:self];
	[stagedTable setTarget:self];

	[unstagedTable registerForDraggedTypes: [NSArray arrayWithObject:FileChangesTableViewType]];
	[stagedTable registerForDraggedTypes: [NSArray arrayWithObject:FileChangesTableViewType]];
}

// FIXME: Find a proper place for this method -- this is not it.
- (void)ignoreFiles:(NSArray<PBChangedFile *> *)files
{
	// Build output string
	NSMutableArray *fileList = [NSMutableArray array];
	for (PBChangedFile *file in files) {
		NSString *name = file.path;
		if ([name length] > 0)
			[fileList addObject:name];
	}
	NSString *filesAsString = [fileList componentsJoinedByString:@"\n"];

	// Write to the file
	NSString *gitIgnoreName = [commitController.repository gitIgnoreFilename];

	NSStringEncoding enc = NSUTF8StringEncoding;
	NSError *error = nil;
	NSMutableString *ignoreFile;

	if (![[NSFileManager defaultManager] fileExistsAtPath:gitIgnoreName]) {
		ignoreFile = [filesAsString mutableCopy];
	} else {
		ignoreFile = [NSMutableString stringWithContentsOfFile:gitIgnoreName usedEncoding:&enc error:&error];
		if (error) {
			[[commitController.repository windowController] showErrorSheet:error];
			return;
		}
		// Add a newline if not yet present
		if ([ignoreFile characterAtIndex:([ignoreFile length] - 1)] != '\n')
			[ignoreFile appendString:@"\n"];
		[ignoreFile appendString:filesAsString];
	}

	[ignoreFile writeToFile:gitIgnoreName atomically:YES encoding:enc error:&error];
	if (error)
		[[commitController.repository windowController] showErrorSheet:error];
}

# pragma mark Context Menu methods
- (BOOL) allSelectedCanBeIgnored:(NSArray *)selectedFiles
{
	if ([selectedFiles count] == 0)
	{
		return NO;
	}
	for (PBChangedFile *selectedItem in selectedFiles) {
		if (selectedItem.status != NEW) {
			return NO;
		}
	}
	return YES;
}

+ (NSString *) getNameOfFirstFile:(NSArray<PBChangedFile *> *) selectedFiles {
	return selectedFiles.firstObject.path.lastPathComponent;
}


+ (BOOL) canDiscardAnyFileIn:(NSArray<PBChangedFile *> *)files {
	for (PBChangedFile *file in files)
	{
		if (file.hasUnstagedChanges)
		{
			return YES;
		}
	}
	return NO;
}

+ (BOOL) shouldTrashInsteadOfDiscardAnyFileIn:(NSArray<PBChangedFile *> *)files {
	for (PBChangedFile *file in files)
	{
		if (file.status != NEW)
		{
			return NO;
		}
	}
	return YES;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([self respondsToSelector:[menuItem action]])
        return YES;

    if ([commitController respondsToSelector:[menuItem action]])
        return YES;

    return [[commitController nextResponder] validateMenuItem:menuItem];
}

- (void) stageSelectedFiles
{
	[commitController.index stageFiles:unstagedFilesController.selectedObjects];
	[self.class establishFutureSelection:unstagedFilesController];
}

- (void) unstageSelectedFiles
{
	[commitController.index unstageFiles:stagedFilesController.selectedObjects];
	[self.class establishFutureSelection:stagedFilesController];
}

+ (void) establishFutureSelection:(NSArrayController *) controller
{
	NSUInteger currentSelectionIndex = controller.selectionIndex;
	dispatch_async(dispatch_get_main_queue(), ^{
		NSUInteger newSelectionIndex = MIN(currentSelectionIndex, [controller.arrangedObjects count] - 1);
		controller.selectionIndex = newSelectionIndex;
	});
}

- (void) openFilesAction:(NSArray<PBChangedFile *> *)files
{
	[PBOpenFiles openFiles:files with:commitController.repository.workingDirectoryURL];
}

- (void) ignoreFilesAction:(NSArray<PBChangedFile *> *)files
{
	if (files.count == 0)
		return;

	[self ignoreFiles:files];
	[commitController.index refresh];
}

- (void) showInFinderAction:(NSArray<PBChangedFile *> *)files
{
	[PBOpenFiles showInFinder:files with:commitController.repository.workingDirectoryURL];
}

- (void) moveToTrash:(NSArray<PBChangedFile *> *)files
{
	NSURL *workingDirectoryURL = commitController.repository.workingDirectoryURL;
	
	BOOL anyTrashed = NO;
	for (PBChangedFile *file in files)
	{
		NSURL* fileURL = [workingDirectoryURL URLByAppendingPathComponent:[file path]];
		
		NSError* error = nil;
		NSURL* resultURL = nil;
		if ([[NSFileManager defaultManager] trashItemAtURL:fileURL
										  resultingItemURL:&resultURL
													 error:&error])
		{
			anyTrashed = YES;
		}
	}
	if (anyTrashed)
	{
		[commitController.index refresh];
	}
}

- (void) discardChangesForFilesAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[alert window] orderOut:nil];

	if (returnCode == NSAlertDefaultReturn) {
		[commitController.index discardChangesForFiles:(__bridge NSArray*)contextInfo];
	}
}

- (void) discardChangesForFiles:(NSArray<PBChangedFile *> *)files force:(BOOL)force
{
	if (!force) {
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Discard changes", @"Title for Discard Changes sheet")
                                         defaultButton:nil
                                       alternateButton:NSLocalizedString(@"Cancel", @"Cancel button in Discard Changes sheet")
                                           otherButton:nil
                             informativeTextWithFormat:NSLocalizedString(@"Are you sure you wish to discard the changes to this file?\n\nYou cannot undo this operation.", @"Informative text for Discard Changes sheet")];
        [alert beginSheetModalForWindow:[[commitController view] window]
                          modalDelegate:self
                         didEndSelector:@selector(discardChangesForFilesAlertDidEnd:returnCode:contextInfo:)
                            contextInfo:(__bridge_retained void*)files];
	} else {
		[commitController.index discardChangesForFiles:files];
    }
}

# pragma mark TableView icon delegate
- (void)tableView:(NSTableView*)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)tableColumn row:(NSInteger)rowIndex
{
	id controller = [tableView tag] == 0 ? unstagedFilesController : stagedFilesController;
	[[tableColumn dataCell] setImage:[[[controller arrangedObjects] objectAtIndex:rowIndex] icon]];
}

- (void) tableClicked:(NSTableView *) tableView
{
	NSArrayController *controller = [tableView tag] == 0 ? unstagedFilesController : stagedFilesController;

	NSIndexSet *selectionIndexes = [tableView selectedRowIndexes];
	NSArray *files = [[controller arrangedObjects] objectsAtIndexes:selectionIndexes];
	if ([tableView tag] == 0) {
		[commitController.index stageFiles:files];
	}
	else {
		[commitController.index unstageFiles:files];
	}
}

- (void) rowClicked:(NSCell *)sender
{
	NSTableView *tableView = (NSTableView *)[sender controlView];
	if([tableView numberOfSelectedRows] != 1)
		return;
	[self tableClicked: tableView];
}

- (BOOL) tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
    // Copy the row numbers to the pasteboard.
    [pboard declareTypes:[NSArray arrayWithObjects:FileChangesTableViewType, NSFilenamesPboardType, nil] owner:self];

	// Internal, for dragging from one tableview to the other
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pboard setData:data forType:FileChangesTableViewType];

	// External, to drag them to for example XCode or Textmate
	NSArrayController *controller = [tv tag] == 0 ? unstagedFilesController : stagedFilesController;
	NSArray *files = [controller.arrangedObjects objectsAtIndexes:rowIndexes];
	NSURL *workingDirectoryURL = commitController.repository.workingDirectoryURL;

	NSMutableArray<NSURL *> *URLs = [NSMutableArray arrayWithCapacity:rowIndexes.count];
	for (PBChangedFile *file in files) {
		[URLs addObject:[workingDirectoryURL URLByAppendingPathComponent:file.path]];
	}
	[pboard writeObjects:URLs];
	
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tableView
				validateDrop:(id <NSDraggingInfo>)info
				 proposedRow:(NSInteger)row
	   proposedDropOperation:(NSTableViewDropOperation)operation
{
	if ([info draggingSource] == tableView)
		return NSDragOperationNone;

	[tableView setDropRow:-1 dropOperation:NSTableViewDropOn];
    return NSDragOperationCopy;
}

- (BOOL)tableView:(NSTableView *)aTableView
	   acceptDrop:(id <NSDraggingInfo>)info
			  row:(NSInteger)row
	dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard* pboard = [info draggingPasteboard];
    NSData* rowData = [pboard dataForType:FileChangesTableViewType];
    NSIndexSet* rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];

	NSArrayController *controller = [aTableView tag] == 0 ? stagedFilesController : unstagedFilesController;
	NSArray *files = [[controller arrangedObjects] objectsAtIndexes:rowIndexes];

	if ([aTableView tag] == 0) {
		[commitController.index unstageFiles:files];
	}
	else {
		[commitController.index stageFiles:files];
	}

	return YES;
}

# pragma mark Key View Chain

-(NSView *)nextKeyViewFor:(NSView *)view
{
    return [commitController nextKeyViewFor:view];
}

-(NSView *)previousKeyViewFor:(NSView *)view
{
    return [commitController previousKeyViewFor:view];
}

@end
