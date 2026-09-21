//
//  PBSourceViewGitWorktreeItem.h
//  GitX
//

#import <Foundation/Foundation.h>
#import "PBSourceViewItem.h"

@class PBGitWorktree;

NS_ASSUME_NONNULL_BEGIN

@interface PBSourceViewGitWorktreeItem : PBSourceViewItem

+ (instancetype)itemWithWorktree:(PBGitWorktree *)worktree;

@property (nonatomic, readonly) PBGitWorktree *worktree;
@property (nonatomic, readonly) NSURL *URL;

// What the row says about itself on hover: where its HEAD is, and why it is
// locked or prunable when it is either.
@property (nonatomic, readonly) NSString *statusDescription;

@end

NS_ASSUME_NONNULL_END
