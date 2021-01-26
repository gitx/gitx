//
//  PBSourceViewBadge.m
//  GitX
//
//  Created by Nathan Kinsinger on 2/13/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBSourceViewBadge.h"


@implementation PBSourceViewBadge


+ (NSColor *)badgeHighlightColor
{
	return [NSColor colorWithCalibratedHue:0.612 saturation:0.275 brightness:0.735 alpha:1.000];
}


+ (NSColor *)badgeBackgroundColor
{
	return [NSColor colorWithCalibratedWhite:0.6 alpha:1.00];
}


+ (NSColor *)badgeColorForCell:(NSTableCellView *)cell
{
	if ([cell backgroundStyle] == NSBackgroundStyleDark)
		return [NSColor whiteColor];

	if ([[cell window] isMainWindow])
		return [self badgeHighlightColor];

	return [self badgeBackgroundColor];
}


+ (NSColor *)badgeTextColorForCell:(NSTableCellView *)cell
{
	if ([cell backgroundStyle] != NSBackgroundStyleDark)
		return [NSColor whiteColor];

	if (![[cell window] isKeyWindow]) {
		if ([[cell window] isMainWindow]) {
			return [self badgeHighlightColor];
		} else {
			return [self badgeBackgroundColor];
		}
	}

	return [self badgeBackgroundColor];
}


+ (NSMutableDictionary *)badgeTextAttributes
{
	NSMutableDictionary *badgeTextAttributes = nil;
	if (!badgeTextAttributes) {
		NSMutableParagraphStyle *centerStyle = [[NSMutableParagraphStyle alloc] init];
		[centerStyle setAlignment:NSCenterTextAlignment];

		badgeTextAttributes = [NSMutableDictionary dictionary];
		[badgeTextAttributes setObject:[NSFont boldSystemFontOfSize:[NSFont systemFontSize] - 2] forKey:NSFontAttributeName];
		[badgeTextAttributes setObject:centerStyle forKey:NSParagraphStyleAttributeName];
	}

	return badgeTextAttributes;
}


#pragma mark -
#pragma mark badges

+ (NSImage *)badge:(NSString *)badge forCell:(NSTableCellView *)cell
{
	NSColor *badgeColor = [self badgeColorForCell:cell];

	NSColor *textColor = [self badgeTextColorForCell:cell];
	NSMutableDictionary *badgeTextAttributes = [self badgeTextAttributes];
	[badgeTextAttributes setObject:textColor forKey:NSForegroundColorAttributeName];
	NSAttributedString *badgeString = [[NSAttributedString alloc] initWithString:badge attributes:badgeTextAttributes];

	CGFloat imageHeight = ceil([badgeString size].height);
	CGFloat radius = ceil(imageHeight / 4) * 2;
	CGFloat minWidth = ceil(radius * 2.5);

	CGFloat imageWidth = ceil([badgeString size].width + radius);
	if (imageWidth < minWidth)
		imageWidth = minWidth;
	NSRect badgeRect = NSMakeRect(0, 0, imageWidth, imageHeight);

	NSBezierPath *badgePath = [NSBezierPath bezierPathWithRoundedRect:badgeRect xRadius:radius yRadius:radius];

	NSImage *badgeImage = [[NSImage alloc] initWithSize:badgeRect.size];
	[badgeImage lockFocus];

	[badgeColor set];
	[badgePath fill];

	[badgeString drawInRect:badgeRect];

	[badgeImage unlockFocus];

	return badgeImage;
}

+ (NSImage *)checkedOutBadgeForCell:(NSTableCellView *)cell
{
	return [self badge:@"✔" forCell:cell];
}

+ (NSImage *)numericBadge:(NSInteger)number forCell:(NSTableCellView *)cell
{
	return [self badge:[NSString stringWithFormat:@"%ld", number] forCell:cell];
}

@end
