//
//  NSAppearance+PBDarkMode.h
//  GitX
//
//  Created by Etienne on 18/11/2018.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSAppearance (PBDarkMode)
- (BOOL)isDarkMode;
@end

@interface NSApplication (PBDarkMode)
- (BOOL)isDarkMode;
@end

NS_ASSUME_NONNULL_END
