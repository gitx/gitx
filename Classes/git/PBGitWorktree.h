//
//  PBGitWorktree.h
//  GitX
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, PBGitWorktreeLinkStyle) {
	PBGitWorktreeLinkStyleUnknown,
	PBGitWorktreeLinkStyleAbsolute,
	PBGitWorktreeLinkStyleRelative,
	PBGitWorktreeLinkStyleMixed,
};

// One record of `git worktree list --porcelain`. A worktree is on a branch, on
// a detached HEAD, or bare, and a bare one reports no HEAD at all.
@interface PBGitWorktree : NSObject

// Records are framed on their `worktree` line and ended by a blank one, since
// a bare repository's record carries neither a HEAD nor a branch.
+ (NSArray<PBGitWorktree *> *)worktreesFromPorcelain:(NSString *)porcelain currentWorktreeAtPath:(nullable NSString *)currentPath;

// Reads the link files of each linked worktree the way `git worktree repair`
// checks them, which the porcelain does not report: once the main folder
// moves, a link still naming the old place is broken.
+ (void)checkLinksOfWorktrees:(NSArray<PBGitWorktree *> *)worktrees commonDirectory:(NSString *)commonDirectory;

+ (nullable NSString *)firstLineOfFileAtPath:(NSString *)path;

// The style the linked worktrees' links share, or Mixed when they differ.
+ (PBGitWorktreeLinkStyle)linkStyleOfWorktrees:(NSArray<PBGitWorktree *> *)worktrees;

@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly, nullable) NSString *HEAD;
@property (nonatomic, readonly, nullable) NSString *branchRefName;

@property (nonatomic, readonly, getter=isBare) BOOL bare;
@property (nonatomic, readonly, getter=isDetached) BOOL detached;
@property (nonatomic, readonly, getter=isCurrent) BOOL current;
@property (nonatomic, readonly, getter=isMain) BOOL main;

@property (nonatomic, readonly, getter=isLocked) BOOL locked;
@property (nonatomic, readonly, nullable) NSString *lockReason;

@property (nonatomic, readonly, getter=isPrunable) BOOL prunable;
@property (nonatomic, readonly, nullable) NSString *prunableReason;

@property (nonatomic, readonly) PBGitWorktreeLinkStyle linkStyle;
@property (nonatomic, readonly, getter=hasBrokenLink) BOOL brokenLink;
// Where the folder of a worktree nested in the main folder went when the main
// folder moved; git still lists it at the old place.
@property (nonatomic, readonly, nullable) NSString *movedPath;

@end

NS_ASSUME_NONNULL_END
