//
//  PBDialogWarningTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitDefaults.h"
#import "PBPrefsWindowController.h"

@interface PBKeyViewRecordingWindow : NSWindow
@property NSUInteger nextKeyViewRequests;
@property NSUInteger previousKeyViewRequests;
@end

@implementation PBKeyViewRecordingWindow

- (void)selectNextKeyView:(id)sender
{
	self.nextKeyViewRequests++;
}

- (void)selectPreviousKeyView:(id)sender
{
	self.previousKeyViewRequests++;
}

@end

@interface PBDialogWarningTests : XCTestCase {
	NSString *suiteName;
	NSUserDefaults *testDefaults;
}
@end

@implementation PBDialogWarningTests

- (void)setUp
{
	[super setUp];
	suiteName = @"net.phere.GitXTests.DialogWarnings";
	testDefaults = [[NSUserDefaults alloc] initWithSuiteName:suiteName];
	[PBGitDefaults useUserDefaults:testDefaults];
}

- (void)tearDown
{
	[PBGitDefaults useUserDefaults:nil];
	[testDefaults removePersistentDomainForName:suiteName];
	[super tearDown];
}

- (NSString *)classesDirectory
{
	NSString *sourceFile = [NSString stringWithUTF8String:__FILE__];
	return [[[sourceFile stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Classes"];
}

- (NSDictionary<NSString *, NSString *> *)identifierConstants
{
	NSString *header = [NSString stringWithContentsOfFile:[[self classesDirectory] stringByAppendingPathComponent:@"git/PBGitDefaults.h"]
												 encoding:NSUTF8StringEncoding
													error:NULL];
	NSRegularExpression *define = [NSRegularExpression regularExpressionWithPattern:@"#define (kDialog\\w+) @\"([^\"]*)\"" options:0 error:NULL];
	NSMutableDictionary *constants = [NSMutableDictionary dictionary];
	for (NSTextCheckingResult *match in [define matchesInString:header options:0 range:NSMakeRange(0, header.length)])
		constants[[header substringWithRange:[match rangeAtIndex:1]]] = [header substringWithRange:[match rangeAtIndex:2]];
	return constants;
}

- (NSSet<NSString *> *)registeredIdentifiers
{
	NSMutableSet *identifiers = [NSMutableSet set];
	for (PBDialogWarning *warning in [PBGitDefaults dialogWarnings])
		[identifiers addObject:warning.identifier];
	return identifiers;
}

// Every non-nil identifier passed to confirmDialog:suppressionIdentifier: is
// found by reading the sources, so a new dialog cannot be added without an
// entry for it in the preferences list.
- (void)testEverySuppressibleDialogIsRegistered
{
	NSDictionary<NSString *, NSString *> *constants = [self identifierConstants];
	NSSet<NSString *> *registered = [self registeredIdentifiers];
	NSRegularExpression *argument = [NSRegularExpression regularExpressionWithPattern:@"suppressionIdentifier:\\s*(@\"([^\"]*)\"|\\w+)" options:0 error:NULL];

	NSUInteger callSites = 0;
	NSDirectoryEnumerator *files = [[NSFileManager defaultManager] enumeratorAtPath:[self classesDirectory]];
	for (NSString *file in files) {
		if (![file.pathExtension isEqualToString:@"m"])
			continue;

		NSString *source = [NSString stringWithContentsOfFile:[[self classesDirectory] stringByAppendingPathComponent:file] encoding:NSUTF8StringEncoding error:NULL];
		for (NSTextCheckingResult *match in [argument matchesInString:source options:0 range:NSMakeRange(0, source.length)]) {
			NSString *token = [source substringWithRange:[match rangeAtIndex:1]];
			if ([token isEqualToString:@"nil"] || [token isEqualToString:@"identifier"])
				continue;

			callSites++;
			NSString *identifier = [match rangeAtIndex:2].location != NSNotFound ? [source substringWithRange:[match rangeAtIndex:2]] : constants[token];
			XCTAssertNotNil(identifier, @"%@ passes %@, which is not a literal or a kDialog constant from PBGitDefaults.h", file, token);
			if (identifier)
				XCTAssertTrue([registered containsObject:identifier], @"%@ passes '%@', which is missing from +[PBGitDefaults dialogWarnings]", file, identifier);
		}
	}

	XCTAssertGreaterThan(callSites, 0u, @"No confirmation dialog call sites were found; the scan is broken");
}

- (void)testEveryRegisteredDialogHasAUniqueIdentifierAndText
{
	NSMutableSet *seen = [NSMutableSet set];
	for (PBDialogWarning *warning in [PBGitDefaults dialogWarnings]) {
		XCTAssertGreaterThan(warning.identifier.length, 0u);
		XCTAssertGreaterThan(warning.title.length, 0u, @"%@ has no title", warning.identifier);
		XCTAssertGreaterThan(warning.detail.length, 0u, @"%@ has no description", warning.identifier);
		XCTAssertFalse([seen containsObject:warning.identifier], @"%@ is registered twice", warning.identifier);
		[seen addObject:warning.identifier];
	}
}

- (void)testSuppressingAndUnsuppressingOneDialogLeavesTheOthers
{
	[PBGitDefaults suppressDialogWarningForDialog:kDialogConfirmPush];
	[PBGitDefaults suppressDialogWarningForDialog:kDialogStashDrop];
	[PBGitDefaults unsuppressDialogWarningForDialog:kDialogConfirmPush];

	XCTAssertFalse([PBGitDefaults isDialogWarningSuppressedForDialog:kDialogConfirmPush]);
	XCTAssertTrue([PBGitDefaults isDialogWarningSuppressedForDialog:kDialogStashDrop]);
}

- (void)testResetAllClearsEverySuppression
{
	for (PBDialogWarning *warning in [PBGitDefaults dialogWarnings])
		[PBGitDefaults suppressDialogWarningForDialog:warning.identifier];

	[PBGitDefaults resetAllDialogWarnings];

	for (PBDialogWarning *warning in [PBGitDefaults dialogWarnings])
		XCTAssertFalse([PBGitDefaults isDialogWarningSuppressedForDialog:warning.identifier], @"%@", warning.identifier);
}

- (NSTableView *)preferencesTable
{
	PBPrefsWindowController *controller = (PBPrefsWindowController *)[PBPrefsWindowController sharedPrefsWindowController];
	[controller window];
	return [controller valueForKey:@"dialogWarningsTable"];
}

- (void)testThePreferencesTableListsEveryRegisteredDialog
{
	NSTableView *table = [self preferencesTable];

	XCTAssertNotNil(table);
	XCTAssertEqual(table.numberOfRows, (NSInteger)[PBGitDefaults dialogWarnings].count);
	NSTableColumn *ask = [table tableColumnWithIdentifier:@"skip"];
	for (NSInteger row = 0; row < table.numberOfRows; row++)
		XCTAssertEqualObjects([table.dataSource tableView:table objectValueForTableColumn:ask row:row], @NO);
}

- (void)testTogglingARowInThePreferencesTableChangesTheSuppression
{
	NSTableView *table = [self preferencesTable];
	NSTableColumn *ask = [table tableColumnWithIdentifier:@"skip"];
	NSString *identifier = [PBGitDefaults dialogWarnings][0].identifier;

	[table.dataSource tableView:table setObjectValue:@YES forTableColumn:ask row:0];
	XCTAssertTrue([PBGitDefaults isDialogWarningSuppressedForDialog:identifier]);
	XCTAssertEqualObjects([table.dataSource tableView:table objectValueForTableColumn:ask row:0], @YES);

	[table.dataSource tableView:table setObjectValue:@NO forTableColumn:ask row:0];
	XCTAssertFalse([PBGitDefaults isDialogWarningSuppressedForDialog:identifier]);
}

- (NSTableView *)shownPreferencesTable
{
	PBPrefsWindowController *controller = (PBPrefsWindowController *)[PBPrefsWindowController sharedPrefsWindowController];
	[controller showWindow:nil];
	[controller displayViewForIdentifier:@"Warnings" animate:NO];
	return [controller valueForKey:@"dialogWarningsTable"];
}

- (void)testClickingTheCheckboxOfARowTogglesTheSuppression
{
	NSTableView *table = [self shownPreferencesTable];
	NSString *identifier = [PBGitDefaults dialogWarnings][0].identifier;
	NSWindow *window = table.window;
	NSRect cell = [table frameOfCellAtColumn:0 row:0];
	NSPoint point = [table convertPoint:NSMakePoint(NSMidX(cell), NSMidY(cell)) toView:nil];
	NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;

	NSEvent *down = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:point modifierFlags:0 timestamp:now windowNumber:window.windowNumber context:nil eventNumber:1 clickCount:1 pressure:1];
	NSEvent *up = [NSEvent mouseEventWithType:NSEventTypeLeftMouseUp location:point modifierFlags:0 timestamp:now windowNumber:window.windowNumber context:nil eventNumber:2 clickCount:1 pressure:0];
	[NSApp postEvent:up atStart:NO];
	[NSApp sendEvent:down];

	XCTAssertTrue([PBGitDefaults isDialogWarningSuppressedForDialog:identifier], @"a click on the checkbox must toggle it");
	[(PBPrefsWindowController *)[PBPrefsWindowController sharedPrefsWindowController] close];
}

- (void)testTheListAllowsRowSelectionSoItsCheckboxesTrackClicks
{
	NSTableView *table = [self preferencesTable];
	id<NSTableViewDelegate> delegate = table.delegate;

	if ([delegate respondsToSelector:@selector(tableView:shouldSelectRow:)])
		XCTAssertTrue([delegate tableView:table shouldSelectRow:0]);
}

- (void)testTabAndShiftTabLeaveTheListInOnePress
{
	NSTableView *table = [self preferencesTable];
	XCTAssertEqualObjects(NSStringFromClass([table class]), @"PBDialogWarningsTable");

	PBKeyViewRecordingWindow *window = [[PBKeyViewRecordingWindow alloc] initWithContentRect:NSMakeRect(0, 0, 100, 100) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:YES];
	NSTableView *list = [[NSClassFromString(@"PBDialogWarningsTable") alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
	[window.contentView addSubview:list];

	[list keyDown:[self keyDownWithCharacters:@"\t" keyCode:48]];
	XCTAssertEqual(window.nextKeyViewRequests, 1u);
	XCTAssertEqual(window.previousKeyViewRequests, 0u);

	[list keyDown:[self keyDownWithCharacters:@"\x19" keyCode:48]];
	XCTAssertEqual(window.nextKeyViewRequests, 1u);
	XCTAssertEqual(window.previousKeyViewRequests, 1u);
}

- (NSEvent *)keyDownWithCharacters:(NSString *)characters keyCode:(unsigned short)keyCode
{
	return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0 timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:0 context:nil characters:characters charactersIgnoringModifiers:characters isARepeat:NO keyCode:keyCode];
}

- (void)testResetWarningsClearsTheCheckedRows
{
	PBPrefsWindowController *controller = (PBPrefsWindowController *)[PBPrefsWindowController sharedPrefsWindowController];
	NSTableView *table = [self preferencesTable];
	NSTableColumn *ask = [table tableColumnWithIdentifier:@"skip"];
	[PBGitDefaults suppressDialogWarningForDialog:[PBGitDefaults dialogWarnings][0].identifier];

	[controller resetAllDialogWarnings:nil];

	XCTAssertEqualObjects([table.dataSource tableView:table objectValueForTableColumn:ask row:0], @NO);
}

- (void)testThePreferencesListShowsFourAndAHalfRows
{
	NSTableView *table = [self preferencesTable];
	NSScrollView *scrollView = table.enclosingScrollView;

	XCTAssertEqualWithAccuracy(NSHeight(scrollView.frame), 4.5 * table.rowHeight, 0.5);
	XCTAssertTrue(scrollView.hasVerticalScroller);
	XCTAssertTrue(NSMaxY(scrollView.frame) < NSHeight(scrollView.superview.frame));
}

- (NSString *)selectedPreferencesTabWhenRemembering:(NSString *)remembered
{
	[[PBGitDefaults userDefaults] setObject:remembered forKey:@"PBGitXPreferenceViewIdentifier"];
	PBPrefsWindowController *controller = (PBPrefsWindowController *)[PBPrefsWindowController sharedPrefsWindowController];
	[controller showWindow:nil];
	NSString *selected = controller.window.toolbar.selectedItemIdentifier;
	[controller close];
	return selected;
}

- (void)testARememberedPreferencesTabThatThisBuildLacksOpensTheFirstTab
{
	XCTAssertEqualObjects([self selectedPreferencesTabWhenRemembering:@"No Such Tab"], @"General");
}

- (void)testARememberedPreferencesTabThatExistsIsReopened
{
	XCTAssertEqualObjects([self selectedPreferencesTabWhenRemembering:@"Warnings"], @"Warnings");
}

@end
