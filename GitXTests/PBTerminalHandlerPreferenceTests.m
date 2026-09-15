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
