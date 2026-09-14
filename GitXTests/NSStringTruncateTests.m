//
//  NSStringTruncateTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "NSString_Truncate.h"

@interface NSStringTruncateTests : XCTestCase
@end

@implementation NSStringTruncateTests

- (void)testAStringNoLongerThanTheTargetLengthIsReturnedUnchanged
{
	NSString *result = [@"short" truncateToLength:10 mode:PBNSStringTruncateModeEnd indicator:@"..."];

	XCTAssertEqualObjects(result, @"short");
}

- (void)testEndModeKeepsThePrefixAndAppendsTheIndicator
{
	NSString *result = [@"Fix the git that Homebrew installed" truncateToLength:13 mode:PBNSStringTruncateModeEnd indicator:@"..."];

	XCTAssertEqualObjects(result, @"Fix the gi...");
}

- (void)testStartModePrependsTheIndicatorAndKeepsTheSuffix
{
	NSString *result = [@"Fix the git that Homebrew installed" truncateToLength:13 mode:PBNSStringTruncateModeStart indicator:@"..."];

	XCTAssertEqualObjects(result, @"... installed");
}

- (void)testCenterModeKeepsBothEnds
{
	NSString *result = [@"Fix the git that Homebrew installed" truncateToLength:14 mode:PBNSStringTruncateModeCenter indicator:@"..."];

	XCTAssertEqualObjects(result, @"Fix the...lled");
}

#pragma mark A cut that would split a grapheme drops the whole thing instead

// The emoji is a surrogate pair: two UTF-16 units. A fixed-width cut that
// lands between them used to produce a lone surrogate, which cannot be
// encoded as UTF-8 and shows up as a broken glyph wherever it is displayed.
- (void)testEndModeDoesNotSplitASurrogatePair
{
	NSString *subject = @"Fix this \U0001F600 thing that broke and needs more words";

	for (NSUInteger targetLength = 8; targetLength <= 20; targetLength++) {
		NSString *result = [subject truncateToLength:targetLength mode:PBNSStringTruncateModeEnd indicator:@"..."];

		XCTAssertNotNil([result dataUsingEncoding:NSUTF8StringEncoding],
						 @"truncating to %lu produced a string that isn't valid UTF-8: %@", (unsigned long)targetLength, result);
	}
}

- (void)testStartModeDoesNotSplitASurrogatePair
{
	NSString *subject = @"Some words before the \U0001F600 emoji that broke it";

	for (NSUInteger targetLength = 8; targetLength <= 20; targetLength++) {
		NSString *result = [subject truncateToLength:targetLength mode:PBNSStringTruncateModeStart indicator:@"..."];

		XCTAssertNotNil([result dataUsingEncoding:NSUTF8StringEncoding],
						 @"truncating to %lu produced a string that isn't valid UTF-8: %@", (unsigned long)targetLength, result);
	}
}

- (void)testCenterModeDoesNotSplitASurrogatePair
{
	NSString *subject = @"Words \U0001F600 on \U0001F601 both \U0001F602 sides of the cut points";

	for (NSUInteger targetLength = 8; targetLength <= 30; targetLength++) {
		NSString *result = [subject truncateToLength:targetLength mode:PBNSStringTruncateModeCenter indicator:@"..."];

		XCTAssertNotNil([result dataUsingEncoding:NSUTF8StringEncoding],
						 @"truncating to %lu produced a string that isn't valid UTF-8: %@", (unsigned long)targetLength, result);
	}
}

#pragma mark A target length too small for the indicator degrades instead of crashing

// The indicator always costs ilength characters, so a target length at or below
// that leaves nothing for the string itself, and the cut arithmetic used to run
// off both ends: End underflowed targetLength - ilength into a huge index, and
// Center pushed its tail cut past the end of the string.
- (void)testNoModeCrashesOnATargetLengthTooSmallForTheIndicator
{
	NSString *subject = @"Fix the git that Homebrew installed";
	PBNSStringTruncateMode modes[] = {PBNSStringTruncateModeCenter, PBNSStringTruncateModeStart, PBNSStringTruncateModeEnd};

	for (NSUInteger modeIndex = 0; modeIndex < 3; modeIndex++) {
		for (NSUInteger targetLength = 0; targetLength <= 10; targetLength++) {
			XCTAssertNoThrow([subject truncateToLength:targetLength mode:modes[modeIndex] indicator:@"..."],
							 @"mode %lu truncating to %lu threw", (unsigned long)modeIndex, (unsigned long)targetLength);
		}
	}
}

- (void)testCenterModeKeepsNoTailOnceTheIndicatorFillsHalfTheBudget
{
	NSString *result = [@"Fix the git that Homebrew installed" truncateToLength:4 mode:PBNSStringTruncateModeCenter indicator:@"..."];

	XCTAssertEqualObjects(result, @"Fi...");
}

- (void)testATargetLengthWithNoRoomLeavesJustTheIndicator
{
	NSString *subject = @"Fix the git that Homebrew installed";

	XCTAssertEqualObjects([subject truncateToLength:0 mode:PBNSStringTruncateModeEnd indicator:@"..."], @"...");
	XCTAssertEqualObjects([subject truncateToLength:0 mode:PBNSStringTruncateModeStart indicator:@"..."], @"...");
}

- (void)testAnIndicatorLongerThanTheWholeStringDoesNotCutPastItsEnd
{
	NSString *result = [@"a" truncateToLength:0 mode:PBNSStringTruncateModeCenter indicator:@"-----"];

	XCTAssertEqualObjects(result, @"a-----");
}

@end
