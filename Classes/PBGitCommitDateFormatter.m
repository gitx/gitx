//
//  PBGitCommitDateFormatter.m
//  GitX
//

#import "PBGitCommitDateFormatter.h"

NSString *const PBGitCommitDateFormatDidChangeNotification = @"PBGitCommitDateFormatDidChangeNotification";

// The history list makes one of these per visible row, so the built formatter is
// shared by all of them and rebuilt only when the preference actually moves.
static PBCommitDateFormatSetting builtSetting;
static NSString *builtCustomFormat;
static NSDateFormatter *builtDateFormatter;

static PBCommitDateFormatSetting announcedSetting;
static NSString *announcedCustomFormat;

static BOOL formatsAreEqual(NSString *one, NSString *other)
{
	return (one == other) || [one isEqualToString:other];
}

@implementation PBGitCommitDateFormatter

+ (void)initialize
{
	if (self != [PBGitCommitDateFormatter class])
		return;

	announcedSetting = [PBGitDefaults commitDateFormat];
	announcedCustomFormat = [[PBGitDefaults commitDateCustomFormat] copy];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(userDefaultsChanged:)
												 name:NSUserDefaultsDidChangeNotification
											   object:nil];
}

// Every defaults write reaches here, so the date preference is compared against
// the one last announced before anything is said about it.
+ (void)userDefaultsChanged:(NSNotification *)notification
{
	PBCommitDateFormatSetting setting = [PBGitDefaults commitDateFormat];
	NSString *customFormat = [PBGitDefaults commitDateCustomFormat];

	if ((setting == announcedSetting) && formatsAreEqual(customFormat, announcedCustomFormat))
		return;

	announcedSetting = setting;
	announcedCustomFormat = [customFormat copy];

	[[NSNotificationCenter defaultCenter] postNotificationName:PBGitCommitDateFormatDidChangeNotification object:nil];
}

+ (NSDateFormatter *)dateFormatterForSetting:(PBCommitDateFormatSetting)setting customFormat:(NSString *)customFormat
{
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];

	NSString *pattern = [customFormat stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ((setting == PBCommitDateFormatCustom) && pattern.length) {
		formatter.dateFormat = customFormat;
		return formatter;
	}

	formatter.timeStyle = NSDateFormatterShortStyle;

	switch (setting) {
		case PBCommitDateFormatShort:
			formatter.dateStyle = NSDateFormatterShortStyle;
			break;
		case PBCommitDateFormatMedium:
			formatter.dateStyle = NSDateFormatterMediumStyle;
			break;
		default:
			formatter.dateStyle = NSDateFormatterLongStyle;
			break;
	}

	return formatter;
}

// The preference is read rather than waited for, so a formatter built here is
// the one the preference asks for however the setting got there.
+ (NSDateFormatter *)currentDateFormatter
{
	PBCommitDateFormatSetting setting = [PBGitDefaults commitDateFormat];
	NSString *customFormat = (setting == PBCommitDateFormatCustom) ? [PBGitDefaults commitDateCustomFormat] : nil;

	if (!builtDateFormatter || (setting != builtSetting) || !formatsAreEqual(customFormat, builtCustomFormat)) {
		builtSetting = setting;
		builtCustomFormat = [customFormat copy];
		builtDateFormatter = [self dateFormatterForSetting:setting customFormat:customFormat];
	}

	return builtDateFormatter;
}

- (NSString *)stringForObjectValue:(id)date
{
	if (![date isKindOfClass:[NSDate class]])
		return nil;

	return [[[self class] currentDateFormatter] stringFromDate:date];
}

@end
