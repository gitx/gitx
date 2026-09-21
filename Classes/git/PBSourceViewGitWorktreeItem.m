//
//  PBSourceViewGitWorktreeItem.m
//  GitX
//

#import "PBSourceViewGitWorktreeItem.h"
#import "PBGitWorktree.h"

NS_ASSUME_NONNULL_BEGIN

@interface PBSourceViewGitWorktreeItem ()

@property (nonatomic, strong) PBGitWorktree *worktree;

@end

@implementation PBSourceViewGitWorktreeItem

+ (instancetype)itemWithWorktree:(PBGitWorktree *)worktree
{
	return [[self alloc] initWithWorktree:worktree];
}

- (instancetype)initWithWorktree:(PBGitWorktree *)worktree
{
	self = [self initWithTitle:worktree.path.lastPathComponent revSpecifier:nil];
	if (!self) return nil;

	_worktree = worktree;

	return self;
}

- (NSString *)title
{
	return self.worktree.path.lastPathComponent;
}

- (NSURL *)URL
{
	return [NSURL fileURLWithPath:self.worktree.path];
}

- (NSString *)iconName
{
	return @"WorktreeBranchTemplate";
}

- (NSString *)headDescription
{
	if (self.worktree.isBare)
		return NSLocalizedString(@"Bare repository", @"Sidebar tooltip for a bare worktree");

	if (self.worktree.isDetached) {
		NSString *head = self.worktree.HEAD.length > 7 ? [self.worktree.HEAD substringToIndex:7] : self.worktree.HEAD;
		return [NSString stringWithFormat:NSLocalizedString(@"Detached at %@", @"Sidebar tooltip for a detached worktree"), head ?: @"?"];
	}

	NSString *branch = self.worktree.branchRefName;
	if ([branch hasPrefix:@"refs/heads/"])
		branch = [branch substringFromIndex:[@"refs/heads/" length]];

	return branch ?: self.worktree.path;
}

- (NSString *)statusDescription
{
	NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObject:[self headDescription]];

	if (self.worktree.isCurrent)
		[parts addObject:NSLocalizedString(@"This is the worktree you have open", @"Sidebar tooltip for the current worktree")];

	if (self.worktree.isLocked)
		[parts addObject:self.worktree.lockReason.length
						 ? [NSString stringWithFormat:NSLocalizedString(@"Locked: %@", @"Sidebar tooltip for a locked worktree with a reason"), self.worktree.lockReason]
						 : NSLocalizedString(@"Locked", @"Sidebar tooltip for a locked worktree")];

	if (self.worktree.isPrunable)
		[parts addObject:self.worktree.prunableReason.length
						 ? [NSString stringWithFormat:NSLocalizedString(@"Prunable: %@", @"Sidebar tooltip for a prunable worktree with a reason"), self.worktree.prunableReason]
						 : NSLocalizedString(@"Prunable", @"Sidebar tooltip for a prunable worktree")];

	[parts addObject:self.worktree.path];

	return [parts componentsJoinedByString:@"\n"];
}

@end

NS_ASSUME_NONNULL_END
