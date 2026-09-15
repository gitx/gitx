//
//  PBGitRefLabelColors.h
//  GitX
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

// The one place the ref label colors are written down. The history list draws
// with the NSColors; the commit details pane is handed the same values as CSS.
@interface PBGitRefLabelColors : NSObject

+ (NSColor *)colorForRefType:(nullable NSString *)type;
+ (NSColor *)currentBranchColor;
+ (NSColor *)worktreeBranchColor;

+ (NSDictionary<NSString *, NSString *> *)CSSColors;

@end

NS_ASSUME_NONNULL_END
