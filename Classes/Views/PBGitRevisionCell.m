//
//  PBGitRevisionCell.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevisionCell.h"
#import "PBGitRef.h"
#import "PBGitCommit.h"
#import "PBGitRevSpecifier.h"

#import "NSColor+RGB.h"

NS_ASSUME_NONNULL_BEGIN

const int COLUMN_WIDTH = 10;
const BOOL SHUFFLE_COLORS = NO;

@interface PBGitRevisionCell (){
	CGFloat _leftMargin;
}

@end

@implementation PBGitRevisionCell

- (BOOL)isFlipped {
	return YES;
}

+ (NSArray *)laneColors
{
	static const size_t colorCount = 8;
	static NSArray *laneColors = nil;
	if (!laneColors) {
		float segment = 1.0f / colorCount;
		NSMutableArray *colors = [NSMutableArray new];
		for (size_t i = 0; i < colorCount; ++i) {
			NSColor *newColor = [NSColor colorWithCalibratedHue:(segment * i) saturation:0.7f brightness:0.8f alpha:1.0f];
			[colors addObject:newColor];
		}
		if (SHUFFLE_COLORS) {
			NSMutableArray *shuffledColors = [NSMutableArray new];
			while (colors.count) {
				uint32_t index = arc4random_uniform(colors.count);
				[shuffledColors addObject:colors[index]];
				[colors removeObjectAtIndex:index];
			}
			colors = shuffledColors;
		}
		laneColors = [NSArray arrayWithArray:colors];
	}

	return laneColors;
}

+ (NSColor *)shadowColor
{
	static NSColor *shadowColor = nil;
	if (!shadowColor) {
		uint8_t l = 64;
		shadowColor = [NSColor colorWithR:l G:l B:l];
	}
	return shadowColor;
}
+ (NSColor *)lineShadowColor
{
	static NSColor *shadowColor = nil;
	if (!shadowColor) {
		uint8_t l = 200;
		shadowColor = [NSColor colorWithR:l G:l B:l];
	}
	return shadowColor;
}

- (void) drawLineFromColumn: (int) from toColumn: (int) to inRect: (NSRect) r offset: (int) offset color: (int) c
{
	NSPoint origin = r.origin;

	NSPoint source = NSMakePoint(origin.x + COLUMN_WIDTH * from, origin.y + offset);
	NSPoint center = NSMakePoint( origin.x + COLUMN_WIDTH * to, origin.y + r.size.height * 0.5 + 0.5);

	NSArray* colors = [PBGitRevisionCell laneColors];
	[(NSColor*)[colors objectAtIndex: (c % [colors count])] set];

	if (from == to) {
		// We're drawing a straight line, we can use NSRectFill as a fast path
		CGFloat yOrigin = center.y > source.y ? source.y : center.y;
		CGFloat height = center.y > source.y ? (center.y - source.y) : (source.y - center.y);

		NSRectFill(NSMakeRect(source.x - 1, yOrigin, 2, height));
	} else {
		NSBezierPath * path = [NSBezierPath bezierPath];
		[path setLineWidth:2];
		[path setLineCapStyle:NSRoundLineCapStyle];
		[path moveToPoint: source];
		[path lineToPoint: center];
		[path stroke];
	}
}

- (BOOL) isCurrentCommit
{
	GTOID *thisOID = self.objectValue.OID;

	PBGitRepository* repository = [self.objectValue repository];
	GTOID *currentOID = [repository headOID];

	return [currentOID isEqual:thisOID];
}

- (void) drawCircleInRect: (NSRect) r
{
	const CGFloat outlineWidth = 1.4f;
	static NSImage *circleImage;
	static NSImage *currentCommitCircleImage;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		circleImage = [NSImage imageWithSize:NSMakeSize(10, 10) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
			NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:dstRect];

			[[NSColor blackColor] set];
			[path fill];

			NSRect smallOval = CGRectInset(dstRect, outlineWidth, outlineWidth);
			NSBezierPath *smallPath = [NSBezierPath bezierPathWithOvalInRect:smallOval];

			[[NSColor whiteColor] set];
			[smallPath fill];

			return YES;
		}];

		currentCommitCircleImage = [NSImage imageWithSize:NSMakeSize(10, 10) flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
			NSBezierPath *path = [NSBezierPath bezierPathWithOvalInRect:dstRect];

			[[NSColor blackColor] set];
			[path fill];

			NSRect smallOval = CGRectInset(dstRect, outlineWidth, outlineWidth);
			NSBezierPath *smallPath = [NSBezierPath bezierPathWithOvalInRect:smallOval];

			[[NSColor colorWithCalibratedRed: 0Xfc/256.0 green:0Xa6/256.0 blue: 0X4f/256.0 alpha: 1.0] set];
			[smallPath fill];

			return YES;
		}];
	});

	long c = cellInfo.position;
	NSPoint origin = r.origin;
	NSPoint columnOrigin = { origin.x + COLUMN_WIDTH * c, origin.y};
	NSRect oval = { columnOrigin.x - 5, columnOrigin.y + r.size.height * 0.5 - 5, 10, 10};

	if ([self isCurrentCommit]) {
		[currentCommitCircleImage drawInRect:oval];
	} else {
		[circleImage drawInRect:oval];
	}
}

- (void) drawTriangleInRect: (NSRect) r sign: (char) sign
{
	long c = cellInfo.position;
	int columnHeight = 10;
	int columnWidth = 8;

	NSPoint top;
	if (sign == '<')
		top.x = round(r.origin.x) + 10 * c + 4;
	else {
		top.x = round(r.origin.x) + 10 * c - 4;
		columnWidth *= -1;
	}
	top.y = r.origin.y + (r.size.height - columnHeight) / 2;

	NSBezierPath * path = [NSBezierPath bezierPath];
	// Start at top
	[path moveToPoint: NSMakePoint(top.x, top.y)];
	// Go down
	[path lineToPoint: NSMakePoint(top.x, top.y + columnHeight)];
	// Go left top
	[path lineToPoint: NSMakePoint(top.x - columnWidth, top.y + columnHeight / 2)];
	// Go to top again
	[path closePath];

	[[NSColor whiteColor] set];
	[path fill];
	[[NSColor blackColor] set];
	[path setLineWidth: 2];
	[path stroke];
}

- (NSMutableDictionary*) attributesForRefLabel
{
	NSMutableDictionary *attributes = [[NSMutableDictionary alloc] initWithCapacity:2];
	NSMutableParagraphStyle* style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];

	[style setAlignment:NSCenterTextAlignment];
	[attributes setObject:style forKey:NSParagraphStyleAttributeName];

	[attributes setObject:[NSFont systemFontOfSize:10] forKey:NSFontAttributeName];

	return attributes;
}

- (NSColor*) colorForRef: (PBGitRef*) ref
{
	BOOL isHEAD = [ref.ref isEqualToString:[[[controller repository] headRef] simpleRef]];

	if (isHEAD) {
		return [NSColor colorWithCalibratedRed: 0Xfc/256.0 green:0Xa6/256.0 blue: 0X4f/256.0 alpha: 1.0];
	}

	NSString* type = [ref type];
	if ([type isEqualToString:@"head"]) {
		return [NSColor colorWithCalibratedRed: 0X9a/256.0 green:0Xe2/256.0 blue: 0X84/256.0 alpha: 1.0];
	} else if ([type isEqualToString:@"remote"]) {
		return [NSColor colorWithCalibratedRed: 0xa2/256.0 green:0Xcf/256.0 blue: 0Xef/256.0 alpha: 1.0];
	} else if ([type isEqualToString:@"tag"]) {
		return [NSColor colorWithCalibratedRed: 0Xfc/256.0 green:0Xed/256.0 blue: 0X6f/256.0 alpha: 1.0];
	}

	return [NSColor yellowColor];
}

-(NSArray<NSValue *> *)rectsForRefsinRect:(NSRect) rect;
{
	NSMutableArray<NSValue *> *array = [NSMutableArray array];

	static const int ref_padding = 4;
	static const int ref_spacing = 4;

	NSRect lastRect = rect;
	lastRect.origin.x = round(lastRect.origin.x);
	lastRect.origin.y = round(lastRect.origin.y);

	for (PBGitRef *ref in self.objectValue.refs) {
		NSMutableDictionary* attributes = [self attributesForRefLabel];
		NSSize textSize = [[ref shortName] sizeWithAttributes:attributes];

		NSRect newRect = lastRect;
		newRect.size.width = textSize.width + ref_padding * 2;
		newRect.size.height = textSize.height;
		newRect.origin.y = rect.origin.y + (rect.size.height - newRect.size.height) / 2;

		if (NSContainsRect(rect, newRect)) {
			[array addObject:[NSValue valueWithRect:newRect]];
			lastRect = newRect;
			lastRect.origin.x += (int)lastRect.size.width + ref_spacing;
		}
	}

	return array;
}

- (void) drawLabelAtIndex:(int)index inRect:(NSRect)rect
{
	NSArray *refs = self.objectValue.refs;
	PBGitRef *ref = [refs objectAtIndex:index];

	NSMutableDictionary* attributes = [self attributesForRefLabel];
	NSBezierPath *border = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:2 yRadius:2];
	[[self colorForRef:ref] set];

	[border fill];

//	[[NSColor blackColor] set];
//	[border stroke];
	[[ref shortName] drawInRect:rect withAttributes:attributes];
}

- (void) drawRefsInRect:(NSRect)refRect
{
	[[NSColor blackColor] setStroke];

	int index = 0;
	for (NSValue *rectValue in [self rectsForRefsinRect:refRect])
	{
		NSRect rect = [rectValue rectValue];
		[self drawLabelAtIndex:index inRect:rect];
		++index;
	}
}

- (void)drawRect:(NSRect)dirtyRect
{
	NSRect rect = self.bounds;
	cellInfo = [self.objectValue lineInfo];

	if (cellInfo && ![controller hasNonlinearPath]) {
		float pathWidth = 10 + COLUMN_WIDTH * cellInfo.numColumns;

		NSRect ownRect;
		NSDivideRect(rect, &ownRect, &rect, pathWidth, NSMinXEdge);

		int i;
		struct PBGitGraphLine *lines = cellInfo.lines;
		for (i = 0; i < cellInfo.nLines; i++) {
			if (lines[i].upper == 0)
				[self drawLineFromColumn: lines[i].from toColumn: lines[i].to inRect:ownRect offset: (int)ownRect.size.height color: lines[i].colorIndex];
			else
				[self drawLineFromColumn: lines[i].from toColumn: lines[i].to inRect:ownRect offset: 0 color:lines[i].colorIndex];
		}

		if (cellInfo.sign == '<' || cellInfo.sign == '>')
			[self drawTriangleInRect: ownRect sign: cellInfo.sign];
		else
			[self drawCircleInRect: ownRect];
	}

	if ([self.objectValue refs] && [[self.objectValue refs] count])
		[self drawRefsInRect:rect];
}

- (void) setObjectValue: (PBGitCommit*)object {
	[super setObjectValue:[NSValue valueWithNonretainedObject:object]];

	[self setNeedsDisplay:YES];
	[self setNeedsLayout:YES];
}

- (void)layout {
	[super layout];

	NSRect rect = self.bounds;
	cellInfo = [self.objectValue lineInfo];

	if (cellInfo) {
		float pathWidth = 10 + COLUMN_WIDTH * cellInfo.numColumns;

		NSRect ownRect;
		NSDivideRect(rect, &ownRect, &rect, pathWidth, NSMinXEdge);

		NSArray <NSValue *>* rectValues = [self rectsForRefsinRect:rect];

		if (rectValues.count > 0) {
			const CGFloat PADDING = 4;
			NSRect lastRect = rectValues.lastObject.rectValue;

			rect.size.width -= lastRect.origin.x - rect.origin.x + lastRect.size.width - PADDING;
			rect.origin.x    = lastRect.origin.x + lastRect.size.width + PADDING;
		}

		NSRect frame = self.textField.frame;

		frame.origin.x = floor(rect.origin.x);
		frame.origin.y = floor((self.bounds.size.height - frame.size.height) / 2) - 1;
		frame.size.width = floor(self.bounds.size.width - frame.origin.x);

		self.textField.frame = frame;
	}
}

- (PBGitCommit*) objectValue {
    return [[super objectValue] nonretainedObjectValue];
}

- (int) indexAtX:(CGFloat)x
{
	cellInfo = [self.objectValue lineInfo];
	float pathWidth = 0;
	if (cellInfo && ![controller hasNonlinearPath])
		pathWidth = 10 + 10 * cellInfo.numColumns;

	int index = 0;
	NSRect refRect = NSMakeRect(pathWidth, 0, 1000, 10000);
	for (NSValue *rectValue in [self rectsForRefsinRect:refRect])
	{
		NSRect rect = [rectValue rectValue];
		if (x >= rect.origin.x && x <= (rect.origin.x + rect.size.width))
			return index;
		++index;
	}

	return -1;
}

- (NSRect) rectAtIndex:(int)index
{
	cellInfo = [self.objectValue lineInfo];
	float pathWidth = 0;
	if (cellInfo && ![controller hasNonlinearPath])
		pathWidth = 10 + 10 * cellInfo.numColumns;
	NSRect refRect = NSMakeRect(pathWidth, 0, 1000, 10000);

	return [[[self rectsForRefsinRect:refRect] objectAtIndex:index] rectValue];
}

@end

NS_ASSUME_NONNULL_END
