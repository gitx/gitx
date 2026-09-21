//
//  PBTerminalHandlerPreferenceTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBTerminalUtil.h"

@interface PBTerminalHandlerPreferenceTests : XCTestCase
@end

@implementation PBTerminalHandlerPreferenceTests

// Each handler needs its own Scripting Bridge header and its own API, so the
// menu can only offer the two GitX actually knows how to drive. Terminal comes
// first because it is the registered default and the fallback.
- (void)testTheOfferedHandlersAreTheOnesGitXCanDrive
{
	NSArray<NSString *> *handlers = [PBTerminalUtil supportedHandlers];

	XCTAssertEqualObjects(handlers, (@[ @"com.apple.Terminal", @"com.googlecode.iterm2" ]));
}

- (void)testEverySupportedHandlerHasANameToShow
{
	for (NSString *handler in [PBTerminalUtil supportedHandlers]) {
		XCTAssertNotNil([PBTerminalUtil nameForHandler:handler], @"%@ has no display name", handler);
	}
}

- (void)testAHandlerGitXCannotDriveHasNoName
{
	XCTAssertNil([PBTerminalUtil nameForHandler:@"com.example.someterminal"]);
}

- (void)testASupportedPreferenceIsUsedAsItStands
{
	for (NSString *handler in [PBTerminalUtil supportedHandlers]) {
		XCTAssertEqualObjects([PBTerminalUtil handlerForPreference:handler], handler);
	}
}

// The default is written by hand today, so it can hold anything at all. It used
// to reach -runCommand:inDirectory: unchecked, which logged and then ran
// Terminal anyway; normalizing it here is what lets the popup show a real
// selection rather than an empty one.
- (void)testAPreferenceGitXCannotDriveFallsBackToTerminal
{
	XCTAssertEqualObjects([PBTerminalUtil handlerForPreference:@"com.example.someterminal"], @"com.apple.Terminal");
}

- (void)testAMissingOrEmptyPreferenceFallsBackToTerminal
{
	XCTAssertEqualObjects([PBTerminalUtil handlerForPreference:nil], @"com.apple.Terminal");
	XCTAssertEqualObjects([PBTerminalUtil handlerForPreference:@""], @"com.apple.Terminal");
}

// Opening a tab rides on an iTerm2 Apple Event that Terminal.app has no
// equivalent for, so the preference must stay shut for Terminal.
- (void)testOnlyiTerm2SupportsTabs
{
	XCTAssertTrue([PBTerminalUtil handlerSupportsTabs:@"com.googlecode.iterm2"]);
	XCTAssertFalse([PBTerminalUtil handlerSupportsTabs:@"com.apple.Terminal"]);
}

- (void)testAHandlerGitXCannotDriveDoesNotSupportTabs
{
	XCTAssertFalse([PBTerminalUtil handlerSupportsTabs:@"com.example.someterminal"]);
	XCTAssertFalse([PBTerminalUtil handlerSupportsTabs:nil]);
}

// A handler that is not running opens a window of its own as it launches, so
// asking it for one as well leaves the user with two sessions. Neither the tab
// preference nor a stale window count makes any difference to that.
- (void)testAHandlerThatIsNotRunningIsLeftToOpenItsOwnWindow
{
	XCTAssertEqual([PBTerminalUtil sessionPlanWhenRunning:NO hasOpenWindow:NO openAsTab:NO], PBTerminalSessionPlanLaunchedWindow);
	XCTAssertEqual([PBTerminalUtil sessionPlanWhenRunning:NO hasOpenWindow:NO openAsTab:YES], PBTerminalSessionPlanLaunchedWindow);
	XCTAssertEqual([PBTerminalUtil sessionPlanWhenRunning:NO hasOpenWindow:YES openAsTab:YES], PBTerminalSessionPlanLaunchedWindow);
}

- (void)testARunningHandlerWithAWindowTakesATabOnlyWhenAsked
{
	XCTAssertEqual([PBTerminalUtil sessionPlanWhenRunning:YES hasOpenWindow:YES openAsTab:YES], PBTerminalSessionPlanNewTab);
	XCTAssertEqual([PBTerminalUtil sessionPlanWhenRunning:YES hasOpenWindow:YES openAsTab:NO], PBTerminalSessionPlanNewWindow);
}

- (void)testARunningHandlerWithNoWindowGetsANewOne
{
	XCTAssertEqual([PBTerminalUtil sessionPlanWhenRunning:YES hasOpenWindow:NO openAsTab:YES], PBTerminalSessionPlanNewWindow);
	XCTAssertEqual([PBTerminalUtil sessionPlanWhenRunning:YES hasOpenWindow:NO openAsTab:NO], PBTerminalSessionPlanNewWindow);
}

// `clear` emits ESC[3J before it clears the screen, which throws away the
// scrollback and makes iTerm2 interrupt the new session to ask whether that
// should be allowed. `tput clear` emits only the screen clear, which is all
// GitX wants in a session it has just opened.
- (void)testTheOpeningLineClearsTheScreenWithoutDiscardingScrollback
{
	NSString *line = [PBTerminalUtil shellLineForCommand:@"git status" inDirectory:[NSURL fileURLWithPath:@"/tmp/repo"]];

	XCTAssertTrue([line containsString:@"tput clear"], @"%@", line);
	XCTAssertFalse([line containsString:@"; clear"], @"%@", line);
}

- (void)testTheOpeningLineEntersTheDirectoryAndRunsTheCommand
{
	NSString *line = [PBTerminalUtil shellLineForCommand:@"git status" inDirectory:[NSURL fileURLWithPath:@"/tmp/repo"]];

	XCTAssertTrue([line hasPrefix:@"cd \"/tmp/repo\";"], @"%@", line);
	XCTAssertTrue([line hasSuffix:@"git status"], @"%@", line);
}

- (void)testAnApplicationThatIsNotInstalledIsNotReportedAsInstalled
{
	XCTAssertFalse([PBTerminalUtil isHandlerInstalled:@"com.example.someterminal"]);
	XCTAssertFalse([PBTerminalUtil isHandlerInstalled:nil]);
}

// Terminal.app ships with macOS, so the fallback is always available. If this
// ever fails the popup would be offering a handler that cannot be launched.
- (void)testTerminalIsInstalled
{
	XCTAssertTrue([PBTerminalUtil isHandlerInstalled:@"com.apple.Terminal"]);
}

@end
