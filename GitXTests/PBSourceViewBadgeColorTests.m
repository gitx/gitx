//
//  PBSourceViewBadgeColorTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>

#import "PBSourceViewBadge.h"
#import "PBSidebarTableViewCell.h"

// The colours are chosen from the window the cell sits in, and a test process
// has no way to make one genuinely main, so these fake it. The pairing under
// test is that the checkmark carries the same distinction the capsule does:
// the capsule turns white when the row is emphasized, and the checkmark has
// to take over the colour the capsule gave up.
@interface PBSourceViewBadge (ColorTests)
+ (NSColor *)badgeHighlightColor;
+ (NSColor *)badgeBackgroundColor;
+ (NSColor *)badgeColorForCell:(NSTableCellView *)cell;
+ (NSColor *)badgeTextColorForCell:(NSTableCellView *)cell;
@end

@interface PBMainWindowStub : NSWindow
@end

@implementation PBMainWindowStub
- (BOOL)isMainWindow { return YES; }
- (BOOL)isKeyWindow { return YES; }
@end

@interface PBSourceViewBadgeColorTests : XCTestCase
@end

@implementation PBSourceViewBadgeColorTests

- (NSTableCellView *)cellEmphasized:(BOOL)emphasized inMainWindow:(BOOL)isMain
{
	Class windowClass = isMain ? [PBMainWindowStub class] : [NSWindow class];
	NSWindow *window = [[windowClass alloc] initWithContentRect:NSMakeRect(0, 0, 320, 240)
													 styleMask:NSWindowStyleMaskTitled
													   backing:NSBackingStoreBuffered
														 defer:NO];

	NSTableCellView *cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 160, 20)];
	[[window contentView] addSubview:cell];
	cell.backgroundStyle = emphasized ? NSBackgroundStyleEmphasized : NSBackgroundStyleNormal;

	return cell;
}

- (void)testEmphasizedRowInAMainWindowGivesTheCheckmarkTheHighlightColour
{
	NSTableCellView *cell = [self cellEmphasized:YES inMainWindow:YES];

	XCTAssertEqualObjects([PBSourceViewBadge badgeTextColorForCell:cell],
						  [PBSourceViewBadge badgeHighlightColor],
						  @"a selected row in an active window should show a highlighted checkmark");
}

- (void)testEmphasizedRowInAnInactiveWindowGivesTheCheckmarkTheInactiveColour
{
	NSTableCellView *cell = [self cellEmphasized:YES inMainWindow:NO];

	XCTAssertEqualObjects([PBSourceViewBadge badgeTextColorForCell:cell],
						  [PBSourceViewBadge badgeBackgroundColor],
						  @"a selected row in an inactive window should show a dimmed checkmark");
}

- (void)testUnemphasizedRowKeepsAWhiteCheckmark
{
	XCTAssertEqualObjects([PBSourceViewBadge badgeTextColorForCell:[self cellEmphasized:NO inMainWindow:YES]],
						  [NSColor whiteColor],
						  @"an unselected row draws the checkmark on a coloured capsule");
	XCTAssertEqualObjects([PBSourceViewBadge badgeTextColorForCell:[self cellEmphasized:NO inMainWindow:NO]],
						  [NSColor whiteColor],
						  @"an unselected row draws the checkmark on a coloured capsule");
}

- (void)testTheCheckmarkAndTheCapsuleNeverShareAColour
{
	for (NSNumber *emphasized in @[@YES, @NO]) {
		for (NSNumber *isMain in @[@YES, @NO]) {
			NSTableCellView *cell = [self cellEmphasized:emphasized.boolValue inMainWindow:isMain.boolValue];

			XCTAssertNotEqualObjects([PBSourceViewBadge badgeTextColorForCell:cell],
									 [PBSourceViewBadge badgeColorForCell:cell],
									 @"emphasized=%@ main=%@ leaves the checkmark invisible", emphasized, isMain);
		}
	}
}

@end
