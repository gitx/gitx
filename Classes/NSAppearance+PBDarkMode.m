//
//  NSAppearance+PBDarkMode.m
//  GitX
//
//  Only the global constant definition remains here — the category
//  implementations have been moved to NSAppearance+PBDarkMode.swift.
//

#import "NSAppearance+PBDarkMode.h"
#import <objc/runtime.h>

// This definition satisfies the `extern NSString *const` declaration in the
// header for all Objective-C callers.  The Swift side imports the same value
// as a plain Swift String via the bridging header.
NSString *const PBEffectiveAppearanceChanged = @"PBEffectiveAppearanceChanged";

@implementation NSAppearance (PBDarkMode)

- (BOOL)isDarkMode
{
	NSAppearanceName bestMatch = [self bestMatchFromAppearancesWithNames:@[NSAppearanceNameDarkAqua, NSAppearanceNameAqua]];
	return [bestMatch isEqualToString:NSAppearanceNameDarkAqua];
}

@end

@implementation NSApplication (PBDarkMode)

- (BOOL)isDarkMode
{
	return self.effectiveAppearance.isDarkMode;
}

static char kAppearanceObservationKey;

- (void)registerObserverForAppearanceChanges:(id)observer
{
	// Use traditional KVO addObserver method
	[self addObserver:self
		   forKeyPath:@"effectiveAppearance"
			  options:NSKeyValueObservingOptionNew
			  context:&kAppearanceObservationKey];

	// Store the observer reference
	objc_setAssociatedObject(self, &kAppearanceObservationKey, observer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	if (context == &kAppearanceObservationKey) {
		id observer = objc_getAssociatedObject(self, &kAppearanceObservationKey);
		[[NSNotificationCenter defaultCenter] postNotificationName:PBEffectiveAppearanceChanged
															object:observer];
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

@end

