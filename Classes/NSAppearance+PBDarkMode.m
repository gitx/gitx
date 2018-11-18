//
//  NSAppearance+PBDarkMode.m
//  GitX
//
//  Created by Etienne on 18/11/2018.
//

#import "NSAppearance+PBDarkMode.h"

@implementation NSAppearance (PBDarkMode)

- (BOOL)isDarkMode
{
	if (@available(macOS 10.14, *)) {
		if ([self bestMatchFromAppearancesWithNames:@[NSAppearanceNameDarkAqua, NSAppearanceNameAqua]] == NSAppearanceNameDarkAqua)
			return YES;
		return NO;
	} else {
		return NO;
	}
}

@end

@implementation NSApplication (PBDarkMode)

- (BOOL)isDarkMode
{
	return self.effectiveAppearance.isDarkMode;
}

@end
