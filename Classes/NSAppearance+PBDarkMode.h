//
//  NSAppearance+PBDarkMode.h
//  GitX
//
//  Created by Etienne on 18/11/2018.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const PBEffectiveAppearanceChanged;

@interface NSAppearance (PBDarkMode)
- (BOOL)isDarkMode;
@end

@interface NSApplication (PBDarkMode)
- (BOOL)isDarkMode;
- (void)registerObserverForAppearanceChanges:(id)observer;
@end

NS_ASSUME_NONNULL_END
