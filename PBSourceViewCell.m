//
//  PBSourceViewCell.m
//  GitX
//
//  Created by Nathan Kinsinger on 1/7/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBSourceViewCell.h"
#import "PBGitSidebarController.h"
#import "PBSourceViewBadge.h"

@interface PBSourceViewCell()
- (NSRect)infoButtonRectForBounds:(NSRect)bounds;
@end

@implementation PBSourceViewCell
@synthesize iInfoButtonAction;
@synthesize showsActionButton;
@synthesize badge;

# pragma mark context menu delegate methods

- init {
	if ((self = [super init])) {

	}
	return self;
}

- (NSMenu *) menuForEvent:(NSEvent *)event inRect:(NSRect)rect ofView:(NSOutlineView *)view
{
    NSPoint point = [self.controlView convertPoint:[event locationInWindow] fromView:nil];
	NSInteger row = [view rowAtPoint:point];
	
	PBGitSidebarController *controller = [view delegate];
	
	return [controller menuForRow:row];
}


#pragma mark drawing

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)outlineView
{
	if(badge){		
		NSImage *checkedOutImage = [PBSourceViewBadge badge:badge forCell:self];
		NSSize imageSize = [checkedOutImage size];
		NSRect imageFrame;
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, imageSize.width + 3, NSMaxXEdge);
		imageFrame.size = imageSize;
		
		if ([outlineView isFlipped])
			imageFrame.origin.y += floor((cellFrame.size.height + imageFrame.size.height) / 2);
		else
			imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
		
		[checkedOutImage compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
	}
	
	[super drawWithFrame:cellFrame inView:outlineView];
}


#pragma mark -
#pragma mark Button support

- (NSRect)infoButtonRectForBounds:(NSRect)bounds {
	CGFloat infoButtonWidth = 17.0f;
	CGFloat infoButtonHeight = 11.0f;
	return NSMakeRect(NSMaxX(bounds) - infoButtonWidth, NSMinY(bounds) + (NSHeight(bounds) - infoButtonHeight)/2.0f, infoButtonWidth, infoButtonHeight);
}

- (NSImage *)infoButtonImage {
    // Construct an image name based on our current state
    NSString *imageName = [NSString stringWithFormat:@"sourceListAction%@.png", 
						   //[self isHighlighted] ? @"selected" : @"normal", 
						   iMouseDownInInfoButton ? @"Over" : 
						   iMouseHoveredInInfoButton ? @"Over" : @""];
    return [NSImage imageNamed:imageName];
}

- (void)drawInteriorWithFrame:(NSRect)bounds inView:(NSView *)controlView {
	[super drawInteriorWithFrame:bounds inView:controlView];
	
	if (showsActionButton) {
		NSRect infoButtonRect = [self infoButtonRectForBounds:bounds];
		NSImage *anImage = [self infoButtonImage];
		[anImage setFlipped:[controlView isFlipped]];
		[anImage drawInRect:infoButtonRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
}


//- (NSUInteger)hitTestForEvent:(NSEvent *)event inRect:(NSRect)cellFrame ofView:(NSView *)controlView {
//	if (showsActionButton) {
//		NSPoint point = [controlView convertPoint:[event locationInWindow] fromView:nil];
//		//	
//		//    NSRect titleRect = [self titleRectForBounds:cellFrame];
//		//    if (NSMouseInRect(point, titleRect, [controlView isFlipped])) {
//		//        return NSCellHitContentArea | NSCellHitEditableTextArea;
//		//    } 
//		//    
//		//    NSRect imageRect = [self imageRectForBounds:cellFrame];
//		//    if (NSMouseInRect(point, imageRect, [controlView isFlipped])) {
//		//        return NSCellHitContentArea;
//		//    }
//		//	
//		//    // Did we hit the sub title?
//		//    NSAttributedString *attributedSubTitle = [self attributedSubTitle];
//		//    if ([attributedSubTitle length] > 0) {
//		//        NSRect attributedSubTitleRect = [self rectForSubTitleBasedOnTitleRect:titleRect inBounds:cellFrame];
//		//        if (NSMouseInRect(point, attributedSubTitleRect, [controlView isFlipped])) {
//		//            // Notice that this text isn't an editable area. Clicking on it won't begin an editing session.
//		//            return NSCellHitContentArea;
//		//        }
//		//    }
//		
//		// How about the info button?
//		NSRect infoButtonRect = [self infoButtonRectForBounds:cellFrame];
//		if (NSMouseInRect(point, infoButtonRect, [controlView isFlipped])) {
//			return NSCellHitContentArea | NSCellHitTrackableArea;
//		} 
//	}
//	
//    return [super hitTestForEvent:event inRect:cellFrame ofView:controlView];
//}

//+ (BOOL)prefersTrackingUntilMouseUp {
//    // NSCell returns NO for this by default. If you want to have trackMouse:inRect:ofView:untilMouseUp: always track until the mouse is up, then you MUST return YES. Otherwise, strange things will happen.
//    return YES;
//}

// Mouse tracking -- the only part we want to track is the "info" button
- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(NSView *)controlView untilMouseUp:(BOOL)flag {
//    [self setControlView:controlView];
//	
    NSRect infoButtonRect = [self infoButtonRectForBounds:cellFrame];
    if ([theEvent type] != NSLeftMouseUp) {
        // This is VERY simple event tracking. We simply check to see if the mouse is in the "i" button or not and dispatch entered/exited mouse events
        NSPoint point = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
        BOOL mouseInButton = NSMouseInRect(point, infoButtonRect, [controlView isFlipped]);
        if (iMouseDownInInfoButton != mouseInButton) {
            iMouseDownInInfoButton = mouseInButton;
            [controlView setNeedsDisplayInRect:cellFrame];
        }
        if ([theEvent type] == NSMouseEntered || [theEvent type] == NSMouseExited) {
            [NSApp sendEvent:theEvent];
        }
        // Note that we process mouse entered and exited events and dispatch them to properly handle updates
        theEvent = [[controlView window] nextEventMatchingMask:(NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSMouseEnteredMask | NSMouseExitedMask)];
    }
	
    // Another way of implementing the above code would be to keep an NSButtonCell as an ivar, and simply call trackMouse:inRect:ofView:untilMouseUp: on it, if the tracking area was inside of it. 
	
    NSPoint locationOfTouch = [controlView convertPoint:[theEvent locationInWindow] fromView:nil];
    
    BOOL mouseInButton = NSMouseInRect(locationOfTouch, [self infoButtonRectForBounds:cellFrame], [controlView isFlipped]);
    if (mouseInButton) {
        // show menu
        NSMenu *menu = [self menuForEvent:theEvent inRect:cellFrame ofView:controlView];
        if (menu){
            [NSMenu popUpContextMenu:menu withEvent:theEvent forView:controlView];
        }
    }
    
        if (iMouseDownInInfoButton) {
            // Send the action, and redisplay
            iMouseDownInInfoButton = NO;
            [controlView setNeedsDisplayInRect:cellFrame];
        }
    
    return [super trackMouse:theEvent inRect:cellFrame ofView:controlView untilMouseUp:flag];
    
    
//	
//    // We return YES since the mouse was released while we were tracking. Not returning YES when you processed the mouse up is an easy way to introduce bugs!
//    return YES;
}
 

// Mouse movement tracking -- we have a custom NSOutlineView subclass that automatically lets us add mouseEntered:/mouseExited: support to any cell!
- (void)addTrackingAreasForView:(NSView *)controlView inRect:(NSRect)cellFrame withUserInfo:(NSDictionary *)userInfo mouseLocation:(NSPoint)mouseLocation {
    NSRect infoButtonRect = [self infoButtonRectForBounds:cellFrame];
	
    NSTrackingAreaOptions options = NSTrackingEnabledDuringMouseDrag | NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways;
	
    BOOL mouseIsInside = NSMouseInRect(mouseLocation, infoButtonRect, [controlView isFlipped]);
    if (mouseIsInside) {
        options |= NSTrackingAssumeInside;
        [controlView setNeedsDisplayInRect:cellFrame];
    }
	
    // We make the view the owner, and it delegates the calls back to the cell after it is properly setup for the corresponding row/column in the outlineview
    NSTrackingArea *area = [[NSTrackingArea alloc] initWithRect:infoButtonRect options:options owner:controlView userInfo:userInfo];
    [controlView addTrackingArea:area];
    [area release];
}

- (void)mouseEntered:(NSEvent *)event {
    iMouseHoveredInInfoButton = YES;
    [(NSControl *)[self controlView] updateCell:self];
}

- (void)mouseExited:(NSEvent *)event {
    iMouseHoveredInInfoButton = NO;
    [(NSControl *)[self controlView] updateCell:self];
}



@end
