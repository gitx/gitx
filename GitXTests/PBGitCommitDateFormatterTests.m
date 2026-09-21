//
//  PBGitCommitDateFormatterTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitCommitDateFormatter.h"
#import "PBGitDefaults.h"

@interface PBGitCommitDateFormatterTests : XCTestCase
@property (nonatomic, strong) id settingToPutBack;
@property (nonatomic, strong) id customFormatToPutBack;
@property (nonatomic, strong) NSDate *date;
@end

@implementation PBGitCommitDateFormatterTests

// The tests run in the application, so these preferences are the ones whoever
// runs them has set in GitX. Put back what was there rather than clearing them.
- (void)setUp
{
	[super setUp];

	self.settingToPutBack = [[NSUserDefaults standardUserDefaults] objectForKey:@"PBCommitDateFormat"];
	self.customFormatToPutBack = [[NSUserDefaults standardUserDefaults] objectForKey:@"PBCommitDateCustomFormat"];
	self.date = [NSDate dateWithTimeIntervalSince1970:1789394700];
}

- (void)tearDown
{
	[self putBack:self.settingToPutBack forKey:@"PBCommitDateFormat"];
	[self putBack:self.customFormatToPutBack forKey:@"PBCommitDateCustomFormat"];

	[super tearDown];
}

- (void)putBack:(id)value forKey:(NSString *)key
{
	if (value)
		[[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
}

- (NSString *)stringForSetting:(PBCommitDateFormatSetting)setting customFormat:(NSString *)customFormat
{
	return [[PBGitCommitDateFormatter dateFormatterForSetting:setting customFormat:customFormat] stringFromDate:self.date];
}

- (NSString *)stringForPattern:(NSString *)pattern
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateFormat = pattern;

	return [formatter stringFromDate:self.date];
}

- (NSString *)stringForDateStyle:(NSDateFormatterStyle)dateStyle
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateStyle = dateStyle;
	formatter.timeStyle = NSDateFormatterShortStyle;

	return [formatter stringFromDate:self.date];
}

// The three offered styles are the system's own, so they read the way dates read
// everywhere else on the machine, in whatever language it is set to.
- (void)testEachStyleIsTheSystemStyleOfThatName
{
	XCTAssertEqualObjects([self stringForSetting:PBCommitDateFormatShort customFormat:nil],
						  [self stringForDateStyle:NSDateFormatterShortStyle]);
	XCTAssertEqualObjects([self stringForSetting:PBCommitDateFormatMedium customFormat:nil],
						  [self stringForDateStyle:NSDateFormatterMediumStyle]);
	XCTAssertEqualObjects([self stringForSetting:PBCommitDateFormatLong customFormat:nil],
						  [self stringForDateStyle:NSDateFormatterLongStyle]);
}

- (void)testACustomPatternIsUsedAsItWasWritten
{
	NSString *formatted = [self stringForSetting:PBCommitDateFormatCustom customFormat:@"yyyy-MM-dd HH:mm"];

	XCTAssertEqualObjects(formatted, [self stringForPattern:@"yyyy-MM-dd HH:mm"]);
	XCTAssertNotEqual([formatted rangeOfString:@"^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}$"
									   options:NSRegularExpressionSearch].location,
					  (NSUInteger)NSNotFound,
					  @"'%@' is not the pattern that was asked for", formatted);
}

// A pattern is free text, so it arrives empty both before anything is typed and
// after it is all deleted again. The long style is what the column showed before
// the preference existed, so that is what an unusable pattern falls back to.
- (void)testAnEmptyPatternFallsBackToTheLongStyle
{
	for (NSString *pattern in @[ @"", @"   " ]) {
		XCTAssertEqualObjects([self stringForSetting:PBCommitDateFormatCustom customFormat:pattern],
							  [self stringForDateStyle:NSDateFormatterLongStyle],
							  @"a pattern of '%@' left the column with nothing to show", pattern);
	}

	XCTAssertEqualObjects([self stringForSetting:PBCommitDateFormatCustom customFormat:nil],
						  [self stringForDateStyle:NSDateFormatterLongStyle]);
}

// The setting is an integer in the defaults, which anything at all can write.
- (void)testASettingThatIsNotOfferedFallsBackToTheLongStyle
{
	XCTAssertEqualObjects([self stringForSetting:(PBCommitDateFormatSetting)42 customFormat:nil],
						  [self stringForDateStyle:NSDateFormatterLongStyle]);
}

// The column binds to a commit's date, but a formatter is asked about whatever
// the cell holds, which is nothing at all until the row has a commit.
- (void)testSomethingOtherThanADateIsNotFormatted
{
	PBGitCommitDateFormatter *formatter = [[PBGitCommitDateFormatter alloc] init];

	XCTAssertNil([formatter stringForObjectValue:@"not a date"]);
	XCTAssertNil([formatter stringForObjectValue:nil]);
	XCTAssertNotNil([formatter stringForObjectValue:self.date]);
}

- (void)testTheFormatterInUseFollowsThePreference
{
	[[NSUserDefaults standardUserDefaults] setInteger:PBCommitDateFormatCustom forKey:@"PBCommitDateFormat"];
	[[NSUserDefaults standardUserDefaults] setObject:@"yyyy-MM-dd" forKey:@"PBCommitDateCustomFormat"];

	XCTAssertEqualObjects([[PBGitCommitDateFormatter currentDateFormatter] stringFromDate:self.date], [self stringForPattern:@"yyyy-MM-dd"]);

	[[NSUserDefaults standardUserDefaults] setInteger:PBCommitDateFormatShort forKey:@"PBCommitDateFormat"];

	XCTAssertEqualObjects([[PBGitCommitDateFormatter currentDateFormatter] stringFromDate:self.date],
						  [self stringForDateStyle:NSDateFormatterShortStyle]);
}

#pragma mark The date a column is sized against

- (CGFloat)renderedWidthOf:(NSString *)string
{
	return [string sizeWithAttributes:@{NSFontAttributeName : [NSFont systemFontOfSize:[NSFont systemFontSize]]}].width;
}

// Today's date would do on most days and badly on some: a column sized on the
// first of May has no room for the thirtieth of September. The date used instead
// is fixed, so the estimate does not depend on the day it was made.
- (void)testTheSizingDateDoesNotDependOnToday
{
	NSString *first = [PBGitCommitDateFormatter sizingDateStringForSetting:PBCommitDateFormatLong customFormat:nil];
	NSString *today = [[PBGitCommitDateFormatter dateFormatterForSetting:PBCommitDateFormatLong customFormat:nil] stringFromDate:[NSDate date]];

	XCTAssertEqualObjects(first, [PBGitCommitDateFormatter sizingDateStringForSetting:PBCommitDateFormatLong customFormat:nil]);
	XCTAssertGreaterThanOrEqual([self renderedWidthOf:first], [self renderedWidthOf:today],
								@"'%@' leaves less room than today's '%@'", first, today);
}

// It is rendered rather than written down, so the estimate is in the reader's
// own locale rather than in the one it was written on.
- (void)testTheSizingDateIsRenderedByTheFormatInForce
{
	CGFloat shortest = [self renderedWidthOf:[PBGitCommitDateFormatter sizingDateStringForSetting:PBCommitDateFormatShort customFormat:nil]];
	CGFloat medium = [self renderedWidthOf:[PBGitCommitDateFormatter sizingDateStringForSetting:PBCommitDateFormatMedium customFormat:nil]];
	CGFloat longest = [self renderedWidthOf:[PBGitCommitDateFormatter sizingDateStringForSetting:PBCommitDateFormatLong customFormat:nil]];

	XCTAssertLessThan(shortest, medium);
	XCTAssertLessThan(medium, longest);

	XCTAssertEqualObjects([PBGitCommitDateFormatter sizingDateStringForSetting:PBCommitDateFormatCustom customFormat:@"yyyy-MM-dd"], @"2026-09-28");
}

- (void)testTheSizingDateFollowsThePreference
{
	[[NSUserDefaults standardUserDefaults] setInteger:PBCommitDateFormatShort forKey:@"PBCommitDateFormat"];
	XCTAssertEqualObjects([PBGitCommitDateFormatter sizingDateString],
						  [PBGitCommitDateFormatter sizingDateStringForSetting:PBCommitDateFormatShort customFormat:nil]);

	[[NSUserDefaults standardUserDefaults] setInteger:PBCommitDateFormatLong forKey:@"PBCommitDateFormat"];
	XCTAssertEqualObjects([PBGitCommitDateFormatter sizingDateString],
						  [PBGitCommitDateFormatter sizingDateStringForSetting:PBCommitDateFormatLong customFormat:nil]);
}

#pragma mark Announcing a change

// Rows already on screen keep the string they were given, so a list that is not
// told the format moved goes on showing the old one until it is scrolled.
- (void)testAChangedPreferenceIsAnnounced
{
	[[NSUserDefaults standardUserDefaults] setInteger:PBCommitDateFormatLong forKey:@"PBCommitDateFormat"];
	(void)[PBGitCommitDateFormatter currentDateFormatter];

	XCTNSNotificationExpectation *announced = [[XCTNSNotificationExpectation alloc] initWithName:PBGitCommitDateFormatDidChangeNotification];

	[[NSUserDefaults standardUserDefaults] setInteger:PBCommitDateFormatMedium forKey:@"PBCommitDateFormat"];

	[self waitForExpectations:@[ announced ] timeout:5];
}

@end
