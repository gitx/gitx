//
//  PBGitRefLabelColors.m
//  GitX
//

#import "PBGitRefLabelColors.h"

NS_ASSUME_NONNULL_BEGIN

@implementation PBGitRefLabelColors

+ (NSDictionary<NSString *, NSString *> *)CSSColors
{
	return @{
		@"head" : @"#9ae284",
		@"remote" : @"#a2cfef",
		@"tag" : @"#fced6f",
		@"currentBranch" : @"#fca64f",
	};
}

+ (NSColor *)colorNamed:(NSString *)name
{
	NSString *hex = [self CSSColors][name];
	if (!hex)
		return [NSColor yellowColor];

	unsigned int value = 0;
	[[NSScanner scannerWithString:[hex substringFromIndex:1]] scanHexInt:&value];

	return [NSColor colorWithCalibratedRed:((value >> 16) & 0xff) / 255.0
									 green:((value >> 8) & 0xff) / 255.0
									  blue:(value & 0xff) / 255.0
									 alpha:1.0];
}

+ (NSColor *)colorForRefType:(nullable NSString *)type
{
	return [self colorNamed:type ?: @""];
}

+ (NSColor *)currentBranchColor
{
	return [self colorNamed:@"currentBranch"];
}

@end

NS_ASSUME_NONNULL_END
