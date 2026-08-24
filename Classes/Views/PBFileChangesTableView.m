//
//  PBFileChangesTableView.m
//  GitX
//
//  Created by Pieter de Bie on 09-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBFileChangesTableView.h"
#import "PBGitCommitController.h"

@implementation PBFileChangesTableView

#pragma mark NSTableView overrides

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
	if ([self delegate]) {
		NSPoint eventLocation = [self convertPoint:[theEvent locationInWindow] fromView:nil];
		NSInteger rowIndex = [self rowAtPoint:eventLocation];
		[self selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:YES];
		return [super menuForEvent:theEvent];
	}

	return nil;
}

// Copying only once the drag leaves GitX: the files being dragged are the
// working copy, and a move takes them out of the repository.
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
	if (context == NSDraggingContextOutsideApplication)
		return NSDragOperationCopy;

	return NSDragOperationEvery;
}

#pragma mark NSView overrides

- (BOOL)acceptsFirstResponder
{
	return [self numberOfRows] > 0;
}

@end
