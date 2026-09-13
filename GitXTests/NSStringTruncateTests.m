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

@end
