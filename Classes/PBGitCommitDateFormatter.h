//
//  PBGitCommitDateFormatter.h
//  GitX
//

#import <Cocoa/Cocoa.h>

#import "PBGitDefaults.h"

// Posted when the commit date preference changes, so lists already on screen can
// redraw the dates they are showing.
extern NSString *const PBGitCommitDateFormatDidChangeNotification;

// What a column sized against -sizingDateString allows on top of it: a share of
// the rendered width as breathing room, and the inset the date is drawn with.
// The room is what lets a date that renders wider than the sizing date still fit.
extern const CGFloat PBDateColumnSlack;
extern const CGFloat PBDateColumnInset;

@interface PBGitCommitDateFormatter : NSFormatter

// A setting the user cannot reach through the popup, and a custom format that is
// empty or all spaces, both fall back to the long style rather than showing
// nothing at all.
+ (NSDateFormatter *)dateFormatterForSetting:(PBCommitDateFormatSetting)setting customFormat:(NSString *)customFormat;

+ (NSDateFormatter *)currentDateFormatter;

// A date to size a column against: one that needs about as much room as any the
// format produces. A string rather than a width, so that a caller measures it in
// whatever font it is about to draw it in.
+ (NSString *)sizingDateString;

+ (NSString *)sizingDateStringForSetting:(PBCommitDateFormatSetting)setting customFormat:(NSString *)customFormat;

@end
