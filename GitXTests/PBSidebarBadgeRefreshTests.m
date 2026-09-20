//
//  PBSidebarBadgeRefreshTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>

#import "PBSidebarTableViewCell.h"

// The checked-out badge is a bitmap baked from the window's main state, so a
// cell configured before its window becomes main keeps the inactive colour
// until something unrelated happens to rebuild it. -updateCheckmarkImage
// assigns a freshly built NSImage every time it runs, so a new instance is
// what tells these tests the cell noticed the change.

@interface PBSidebarBadgeRefreshTests : XCTestCase
@end

@implementation PBSidebarBadgeRefreshTests

- (NSWindow *)window
{
	return [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 320, 240)
									   styleMask:NSWindowStyleMaskTitled
										 backing:NSBackingStoreBuffered
										   defer:NO];
}

- (PBSidebarTableViewCell *)checkedOutCellInWindow:(NSWindow *)window
{
	PBSidebarTableViewCell *cell = [[PBSidebarTableViewCell alloc] initWithFrame:NSMakeRect(0, 0, 160, 20)];
	NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 20, 20)];

	// The outlet is weak, so the image view has to be held by the view tree.
	[cell setValue:imageView forKey:@"checkedOutImageView"];
	[cell addSubview:imageView];

	[[window contentView] addSubview:cell];
	cell.isCheckedOut = YES;

	return cell;
}

- (NSImage *)badgeOfCell:(PBSidebarTableViewCell *)cell
{
	return [(NSImageView *)[cell valueForKey:@"checkedOutImageView"] image];
}

- (void)testBadgeIsRebuiltWhenTheWindowBecomesMain
{
	NSWindow *window = [self window];
	PBSidebarTableViewCell *cell = [self checkedOutCellInWindow:window];

	NSImage *before = [self badgeOfCell:cell];
	XCTAssertNotNil(before, @"a checked-out cell should carry a badge");

	[[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidBecomeMainNotification
														object:window];

	XCTAssertFalse([self badgeOfCell:cell] == before,
				   @"the badge should be rebuilt when the window becomes main");
}

- (void)testBadgeIsRebuiltWhenTheWindowResignsMain
{
	NSWindow *window = [self window];
	PBSidebarTableViewCell *cell = [self checkedOutCellInWindow:window];

	NSImage *before = [self badgeOfCell:cell];
	XCTAssertNotNil(before, @"a checked-out cell should carry a badge");

	[[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidResignMainNotification
														object:window];

	XCTAssertFalse([self badgeOfCell:cell] == before,
				   @"the badge should be rebuilt when the window resigns main");
}

- (void)testAnotherWindowChangingStateLeavesTheBadgeAlone
{
	NSWindow *window = [self window];
	PBSidebarTableViewCell *cell = [self checkedOutCellInWindow:window];

	NSImage *before = [self badgeOfCell:cell];
	XCTAssertNotNil(before, @"a checked-out cell should carry a badge");

	[[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidBecomeMainNotification
														object:[self window]];

	XCTAssertTrue([self badgeOfCell:cell] == before,
				  @"a different window becoming main should not touch this badge");
}

@end
