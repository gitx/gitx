//
//  PBGitRevisionRow.m
//  GitX
//
//  Created by Max Langer on 18.01.18.
//

#import "PBGitRevisionRow.h"
#import "PBGitCommit.h"
#import "PBGraphCellInfo.h"
#import "PBHistorySearchController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation PBGitRevisionRow

#pragma mark - Colors

- (NSColor *)searchResultHighlightColorForRow:(NSInteger)rowIndex
{
	// if the row is selected use default colors
	if ([self isSelected]) {
		if ([[self window] isKeyWindow]) {
			if ([[self window] firstResponder] == (NSTableView *)self.controller.commitList) {
				return [NSColor alternateSelectedControlColor];
			}
			return [NSColor selectedControlColor];
		}
		return [NSColor secondarySelectedControlColor];
	}

	// light blue color highlighting search results
	return [NSColor colorWithCalibratedRed:0.751f green:0.831f blue:0.943f alpha:0.800f];
}

- (NSColor *)searchResultHighlightStrokeColorForRow:(NSInteger)rowIndex
{
	if ([self isSelected])
		return [NSColor colorWithCalibratedWhite:0.0f alpha:0.30f];

	return [NSColor colorWithCalibratedWhite:0.0f alpha:0.05f];
}


#pragma mark - Drawing

- (void)drawSelectionInRect:(NSRect)dirtyRect
{
	NSInteger position = [(NSTableView *)self.controller.commitList rowForView:self];

	if ([self.controller.searchController isRowInSearchResults:position]) {
		return;
	}

	[super drawSelectionInRect:dirtyRect];
}

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];

	CGRect rect = self.bounds;
	NSInteger position = [(NSTableView *)self.controller.commitList rowForView:self];

	if ([self.controller.searchController isRowInSearchResults:position]) {
		NSRect highlightRect = NSInsetRect(rect, 1.0f, 1.0f);
		CGFloat radius = highlightRect.size.height / 2.0f;

		NSBezierPath *highlightPath = [NSBezierPath bezierPathWithRoundedRect:highlightRect xRadius:radius yRadius:radius];

		[[self searchResultHighlightColorForRow:position] set];
		[highlightPath fill];

		[[self searchResultHighlightStrokeColorForRow:position] set];
		[highlightPath stroke];
	}
}

@end

NS_ASSUME_NONNULL_END
