/*
 
 File: TrackableOutlineView.m
 
 Abstract: The TrackableOutlineView provides an implementation of updateTrackingAreas
 that automatically delegates to cells which implement the informal
 CellTrackingRect protocol.
 
 Version: 1.0
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by 
 Apple Inc. ("Apple") in consideration of your agreement to the
 following terms, and your use, installation, modification or
 redistribution of this Apple software constitutes acceptance of these
 terms.  If you do not agree with these terms, please do not use,
 install, modify or redistribute this Apple software.

 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software. 
 Neither the name, trademarks, service marks or logos of Apple Inc. 
 may be used to endorse or promote products derived from the Apple
 Software without specific prior written permission from Apple.  Except
 as expressly stated in this notice, no other rights or licenses, express
 or implied, are granted by Apple herein, including but not limited to
 any patent rights that may be infringed by your derivative works or by
 other works in which the Apple Software may be incorporated. 

 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.

 Copyright (C) 2006-2007 Apple Inc. All Rights Reserved. 
 */ 

#import "TrackableOutlineView.h"

#import <AppKit/NSTrackingArea.h>
#import "CellTrackingRect.h" 
#import "PBGitSidebarController.h"

@implementation TrackableOutlineView

- (id)init {
    self = [super init];
    if (self) {
        iMouseRow = -1;
        iMouseCol = -1;
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        iMouseRow = -1;
        iMouseCol = -1;
    }
    return self;
}

- (void)dealloc {
    [iMouseCell release];
    [super dealloc];
}

// Tracking rect support

- (void)updateTrackingAreas {
    for (NSTrackingArea *area in [self trackingAreas]) {
        // We have to uniquely identify our own tracking areas
        if (([area owner] == self) && ([[area userInfo] objectForKey:@"Row"] != nil)) {
            [self removeTrackingArea:area];
        }
    }

     // Find the visible cells that have a non-empty tracking rect and add rects for each of them
    NSRange visibleRows = [self rowsInRect:[self visibleRect]];
    NSIndexSet *visibleColIndexes = [self columnIndexesInRect:[self visibleRect]];

    NSPoint mouseLocation = [self convertPoint:[[self window] convertScreenToBase:[NSEvent mouseLocation]] fromView:nil];
	NSInteger row;
    for (row = visibleRows.location; row < visibleRows.location + visibleRows.length; row++ ) {
        // If it is a "full width" cell, we don't have to go through the rows
        NSCell *fullWidthCell = [self preparedCellAtColumn:-1 row:row];
        if (fullWidthCell) {
            if ([fullWidthCell respondsToSelector:@selector(addTrackingAreasForView:inRect:withUserInfo:mouseLocation:)]) {
                NSInteger col = -1;
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:col], @"Col", [NSNumber numberWithInteger:row], @"Row", nil];
				[fullWidthCell addTrackingAreasForView:self inRect:[self frameOfCellAtColumn:col row:row] withUserInfo:userInfo mouseLocation:mouseLocation];
            }
        } else {
			NSInteger col;
            for (col = [visibleColIndexes firstIndex]; col != NSNotFound; col = [visibleColIndexes indexGreaterThanIndex:col]) {
                NSCell *cell = [self preparedCellAtColumn:col row:row];
                if ([cell respondsToSelector:@selector(addTrackingAreasForView:inRect:withUserInfo:mouseLocation:)]) {
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInteger:col], @"Col", [NSNumber numberWithInteger:row], @"Row", nil];
                    [cell addTrackingAreasForView:self inRect:[self frameOfCellAtColumn:col row:row] withUserInfo:userInfo mouseLocation:mouseLocation];
                }
            }
        }
    }
}

- (void)mouseEntered:(NSEvent *)event {
    // Delegate this to the appropriate cell. In order to allow the cell to maintain state, we copy it and use the copy until the mouse is moved outside of the cell.
    NSDictionary *userInfo = [event userData];
    NSNumber *row = [userInfo valueForKey:@"Row"];
    NSNumber *col = [userInfo valueForKey:@"Col"];
    if (row && col) {
        NSInteger rowVal = [row integerValue]; 
        NSInteger colVal = [col integerValue];
        NSCell *cell = [self preparedCellAtColumn:colVal row:rowVal];
        // Only set the mouseCell properties AFTER calling preparedCellAtColumn:row:.
        if (iMouseCell != cell) {
            [iMouseCell release];
            // Store off the col/row
            iMouseCol = colVal;
            iMouseRow = rowVal;
            // Store a COPY of the cell for use when tracking in an area
            iMouseCell = [cell copy];
            [iMouseCell setControlView:self];
			if ([iMouseCell respondsToSelector:@selector(mouseEntered:)]) {
				[iMouseCell mouseEntered:event];
			}
        }
    }
}

- (void)mouseExited:(NSEvent *)event {
    NSDictionary *userInfo = [event userData];
    NSNumber *row = [userInfo valueForKey:@"Row"];
    NSNumber *col = [userInfo valueForKey:@"Col"];
    if (row && col) {
        NSCell *cell = [self preparedCellAtColumn:[col integerValue] row:[row integerValue]];
        [cell setControlView:self];
		if ([cell respondsToSelector:@selector(mouseExited:)]) {
			[cell mouseExited:event];
		}
        // We are now done with the copied cell
        [iMouseCell release];
        iMouseCell = nil;
        iMouseCol = -1;
        iMouseRow = -1;
    }
}

/* Since NSTableView/NSOutineView uses the same cell to "stamp" out each row, we need to send the mouseEntered/mouseExited events each time it is drawn. The easy hook for this is the preparedCell method. 
*/
- (NSCell *)preparedCellAtColumn:(NSInteger)column row:(NSInteger)row {
    // We check if the selectedCell is nil or not -- the selectedCell is a cell that is currently being edited or tracked. We don't want to return our override if we are in that state.
    if ([self selectedCell] == nil && (row == iMouseRow) && (column == iMouseCol)) {
        return iMouseCell;
    } else {
        return [super preparedCellAtColumn:column row:row];
    }
}

/* In order for the cell to properly update itself with an "updateCell:" call, we must handle the "mouseCell" as a special case
*/
- (void)updateCell:(NSCell *)aCell {
    if (aCell == iMouseCell) {
        [self setNeedsDisplayInRect:[self frameOfCellAtColumn:iMouseCol row:iMouseRow]];
    } else {
        [super updateCell:aCell];
    }
}

@end
