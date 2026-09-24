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
+ (BOOL)badgeTextIsKnockedOutForCell:(NSTableCellView *)cell;
@end

@interface PBMainWindowStub : NSWindow
@end

@implementation PBMainWindowStub
- (BOOL)isMainWindow { return YES; }
- (BOOL)isKeyWindow { return YES; }
@end

static NSInteger PBTransparentPixelCount(NSImage *image)
{
	NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:[image TIFFRepresentation]];
	NSInteger count = 0;

	for (NSInteger y = 0; y < [rep pixelsHigh]; y++)
		for (NSInteger x = 0; x < [rep pixelsWide]; x++)
			if ([[rep colorAtX:x y:y] alphaComponent] < 0.1)
				count++;

	return count;
}

static CGFloat PBRelativeLuminance(NSColor *color)
{
	NSColor *srgb = [color colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
	CGFloat channels[3] = { [srgb redComponent], [srgb greenComponent], [srgb blueComponent] };
	CGFloat weights[3] = { 0.2126, 0.7152, 0.0722 };
	CGFloat luminance = 0;

	for (NSUInteger i = 0; i < 3; i++) {
		CGFloat channel = channels[i];
		luminance += weights[i] * (channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4));
	}

	return luminance;
}

@interface PBSwitchableMainWindowStub : NSWindow
@property (nonatomic, assign) BOOL pretendsToBeMain;
@end

@implementation PBSwitchableMainWindowStub
- (BOOL)isMainWindow
{
	return self.pretendsToBeMain;
}
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

- (PBSidebarTableViewCell *)lockedCellEmphasized:(BOOL)emphasized inWindow:(NSWindow *)window
{
	PBSidebarTableViewCell *cell = [[PBSidebarTableViewCell alloc] initWithFrame:NSMakeRect(0, 0, 160, 20)];
	NSImageView *lock = [[NSImageView alloc] initWithFrame:NSMakeRect(140, 2, 16, 16)];
	[cell addSubview:lock];
	[cell setValue:lock forKey:@"checkedOutImageView"];

	[[window contentView] addSubview:cell];
	cell.backgroundStyle = emphasized ? NSBackgroundStyleEmphasized : NSBackgroundStyleNormal;
	cell.isLocked = YES;

	return cell;
}

- (NSColor *)lockTintOf:(PBSidebarTableViewCell *)cell
{
	return [(NSImageView *)[cell valueForKey:@"checkedOutImageView"] contentTintColor];
}

- (void)testTheLockTakesTheCapsuleColourInEveryState
{
	for (NSNumber *emphasized in @[ @YES, @NO ]) {
		for (NSNumber *isMain in @[ @YES, @NO ]) {
			Class windowClass = isMain.boolValue ? [PBMainWindowStub class] : [NSWindow class];
			NSWindow *window = [[windowClass alloc] initWithContentRect:NSMakeRect(0, 0, 320, 240) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
			PBSidebarTableViewCell *cell = [self lockedCellEmphasized:emphasized.boolValue inWindow:window];

			XCTAssertEqualObjects([self lockTintOf:cell], [PBSourceViewBadge badgeColorForCell:cell],
								  @"emphasized=%@ main=%@ gives the lock another colour than the checkmark's capsule", emphasized, isMain);
		}
	}
}

- (void)testTheLockDimsWhenTheWindowStopsBeingMain
{
	PBSwitchableMainWindowStub *window = [[PBSwitchableMainWindowStub alloc] initWithContentRect:NSMakeRect(0, 0, 320, 240) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
	window.pretendsToBeMain = YES;
	PBSidebarTableViewCell *cell = [self lockedCellEmphasized:NO inWindow:window];
	XCTAssertEqualObjects([self lockTintOf:cell], [PBSourceViewBadge badgeHighlightColor]);

	window.pretendsToBeMain = NO;
	[[NSNotificationCenter defaultCenter] postNotificationName:NSWindowDidResignMainNotification object:window];

	XCTAssertEqualObjects([self lockTintOf:cell], [PBSourceViewBadge badgeBackgroundColor],
						  @"the lock should dim along with the checkmark when the window goes inactive");
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

- (void)testTheInactiveCapsuleIsVisiblyDimmerThanTheActiveOne
{
	CGFloat active = PBRelativeLuminance([PBSourceViewBadge badgeHighlightColor]);
	CGFloat inactive = PBRelativeLuminance([PBSourceViewBadge badgeBackgroundColor]);

	XCTAssertLessThan(inactive, active * 0.8,
					  @"an inactive badge should read as dim, not merely as less blue");
}

- (void)testTheCheckmarkIsKnockedOutOnlyWhileTheWindowIsInactive
{
	XCTAssertTrue([PBSourceViewBadge badgeTextIsKnockedOutForCell:[self cellEmphasized:NO inMainWindow:NO]],
				  @"an inactive window should leave the checkmark hollow");
	XCTAssertFalse([PBSourceViewBadge badgeTextIsKnockedOutForCell:[self cellEmphasized:NO inMainWindow:YES]],
				   @"an active window should draw the checkmark solid");
	XCTAssertFalse([PBSourceViewBadge badgeTextIsKnockedOutForCell:[self cellEmphasized:YES inMainWindow:NO]],
				   @"a selected row carries the colour in the checkmark, so it cannot be hollow");
	XCTAssertFalse([PBSourceViewBadge badgeTextIsKnockedOutForCell:[self cellEmphasized:YES inMainWindow:YES]],
				   @"a selected row carries the colour in the checkmark, so it cannot be hollow");
}

- (void)testTheHollowCheckmarkLetsTheBackgroundThrough
{
	NSImage *inactive = [PBSourceViewBadge checkedOutBadgeForCell:[self cellEmphasized:NO inMainWindow:NO]];
	NSImage *active = [PBSourceViewBadge checkedOutBadgeForCell:[self cellEmphasized:NO inMainWindow:YES]];

	XCTAssertGreaterThan(PBTransparentPixelCount(inactive), PBTransparentPixelCount(active),
						 @"the hollow checkmark should punch through the capsule it sits on");
}

@end
