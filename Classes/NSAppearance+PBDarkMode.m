//
//  NSAppearance+PBDarkMode.m
//  GitX
//
//  Objective-C helpers for detecting the current appearance (dark/light mode).
//

#import "NSAppearance+PBDarkMode.h"
#import <objc/runtime.h>

NSString *const PBEffectiveAppearanceChanged = @"PBEffectiveAppearanceChanged";

// Shared between the KVO registration and the observing token, so the token can
// tell its own changes apart from any it gets registered for elsewhere.
static const void * const kAppearanceObservationContext = &kAppearanceObservationContext;

// AppKit routes appearance changes to NSApplication through its own
// -observeValueForKeyPath:ofObject:change:context: implementation and private
// contexts. Overriding that method on NSApplication in a category shadows
// AppKit's implementation and crashes on appearance change, so observe
// `effectiveAppearance` through this dedicated token object instead.
@interface PBAppearanceObserverToken : NSObject
@property (nonatomic, weak) id observer;
@end

@implementation PBAppearanceObserverToken

- (void)observeValueForKeyPath:(__unused NSString *)keyPath
					  ofObject:(__unused id)object
						change:(__unused NSDictionary<NSKeyValueChangeKey, id> *)change
					   context:(void *)context
{
	if (context != kAppearanceObservationContext) {
		// Not one of our observations; do not forward it up the responder
		// chain, NSObject's default implementation raises on unhandled KVO.
		return;
	}
	id observer = self.observer;
	if (observer) {
		[[NSNotificationCenter defaultCenter] postNotificationName:PBEffectiveAppearanceChanged
															object:observer];
	}
}

@end

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

- (void)registerObserverForAppearanceChanges:(id)observer
{
	PBAppearanceObserverToken *previous = objc_getAssociatedObject(self, &kAppearanceObservationContext);
	if (previous) {
		[self removeObserver:previous forKeyPath:@"effectiveAppearance"];
	}

	PBAppearanceObserverToken *token = [[PBAppearanceObserverToken alloc] init];
	token.observer = observer;
	[self addObserver:token
		   forKeyPath:@"effectiveAppearance"
			  options:0
			  context:(void *)kAppearanceObservationContext];

	// Retain the token so KVO keeps forwarding appearance changes to it.
	objc_setAssociatedObject(self, &kAppearanceObservationContext, token, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
