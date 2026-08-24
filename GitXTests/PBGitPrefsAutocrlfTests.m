//
//  PBGitPrefsAutocrlfTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitPrefsWindowController.h"

// The controller finds the "no value" row of a core.autocrlf pop up by this
// tag. The suite names it the same way the drag suite names the pasteboard
// type it drives, so that the nib and the controller cannot drift apart
// without a test saying so.
static const NSInteger PBGitPrefsAutocrlfUnsetTag = -1;

@interface PBGitPrefsAutocrlfTests : XCTestCase
@property (nonatomic, strong) PBGitPrefsWindowController *controller;
@end

@implementation PBGitPrefsAutocrlfTests

- (void)setUp
{
	[super setUp];

	self.controller = [[PBGitPrefsWindowController alloc] initWithWindowNibName:@"PBGitPrefsWindowController"];
	(void)[self.controller window]; // force the nib, and with it our outlets, to load
}

- (void)tearDown
{
	self.controller = nil;
	[super tearDown];
}

- (void)assertPopUp:(NSPopUpButton *)popUp named:(NSString *)name
{
	XCTAssertNotNil(popUp, @"the %@ pop up should be wired to the nib", name);

	NSMutableArray *taggedTitles = [NSMutableArray array];
	NSMutableArray *untaggedTitles = [NSMutableArray array];
	for (NSMenuItem *item in popUp.itemArray) {
		if (item.tag == PBGitPrefsAutocrlfUnsetTag)
			[taggedTitles addObject:item.title];
		else
			[untaggedTitles addObject:item.title];
	}

	XCTAssertEqual(taggedTitles.count, (NSUInteger)1, @"the %@ pop up should mark exactly one row as the unset row", name);
	XCTAssertEqualObjects(untaggedTitles, (@[ @"false", @"true", @"input" ]), @"every other row of the %@ pop up should read as a value git accepts", name);
}

- (void)testTheRepositoryPopUpMarksTheRowThatStandsForNoValue
{
	[self assertPopUp:self.controller.localAutocrlfPopUp named:@"repository"];
}

- (void)testTheGlobalPopUpMarksTheRowThatStandsForNoValue
{
	[self assertPopUp:self.controller.globalAutocrlfPopUp named:@"global"];
}

@end
