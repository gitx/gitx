//
//  NSAppearance+PBDarkMode.m
//  GitX
//
//  Created by Etienne on 18/11/2018.
//

#import "NSAppearance+PBDarkMode.h"

NSString *const PBEffectiveAppearanceChanged = @"PBEffectiveAppearanceChanged";

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
	if (@available(macOS 10.14, *)) {
		return self.effectiveAppearance.isDarkMode;
	} else {
		return NO;
	}
}

- (void)registerObserverForAppearanceChanges:(id)observer
{
	if (@available(macOS 10.14, *)) {
		/* This leaks the observation, but since it's tied to the life of NSApp
		 * it doesn't matter ;-) */
		[[NSApplication sharedApplication] addObserver:observer keyPath:@"effectiveAppearance" options:0 block:^(MAKVONotification *notification) {
			[[NSNotificationCenter defaultCenter] postNotificationName:PBEffectiveAppearanceChanged object:observer];
		}];
	}
}

@end
