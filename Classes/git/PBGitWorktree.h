//
//  PBGitWorktree.h
//  GitX
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// One record of `git worktree list --porcelain`. A worktree is on a branch, on
// a detached HEAD, or bare, and a bare one reports no HEAD at all.
@interface PBGitWorktree : NSObject

// Records are framed on their `worktree` line and ended by a blank one, since
// a bare repository's record carries neither a HEAD nor a branch.
+ (NSArray<PBGitWorktree *> *)worktreesFromPorcelain:(NSString *)porcelain currentWorktreeAtPath:(nullable NSString *)currentPath;

@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly, nullable) NSString *HEAD;
@property (nonatomic, readonly, nullable) NSString *branchRefName;

@property (nonatomic, readonly, getter=isBare) BOOL bare;
@property (nonatomic, readonly, getter=isDetached) BOOL detached;
@property (nonatomic, readonly, getter=isCurrent) BOOL current;

@property (nonatomic, readonly, getter=isLocked) BOOL locked;
@property (nonatomic, readonly, nullable) NSString *lockReason;

@property (nonatomic, readonly, getter=isPrunable) BOOL prunable;
@property (nonatomic, readonly, nullable) NSString *prunableReason;

@end

NS_ASSUME_NONNULL_END
