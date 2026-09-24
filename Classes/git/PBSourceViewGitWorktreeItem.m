//
//  PBSourceViewGitWorktreeItem.m
//  GitX
//

#import "PBSourceViewGitWorktreeItem.h"
#import "PBGitWorktree.h"
#import "PBGitRef.h"
#import "PBGitRevSpecifier.h"

NS_ASSUME_NONNULL_BEGIN

@interface PBSourceViewGitWorktreeItem ()

@property (nonatomic, strong) PBGitWorktree *worktree;

@end

@implementation PBSourceViewGitWorktreeItem

+ (instancetype)itemWithWorktree:(PBGitWorktree *)worktree
{
	return [[self alloc] initWithWorktree:worktree];
}

// The row stands for the branch parked here, so it carries that branch's rev
// specifier: selecting it moves the history list, exactly as the branch row did
// before it moved into this group.
+ (nullable PBGitRevSpecifier *)revSpecifierForWorktree:(PBGitWorktree *)worktree
{
	if (!worktree.branchRefName)
		return nil;

	return [[PBGitRevSpecifier alloc] initWithRef:[PBGitRef refFromString:worktree.branchRefName]];
}

- (instancetype)initWithWorktree:(PBGitWorktree *)worktree
{
	self = [self initWithTitle:worktree.path.lastPathComponent revSpecifier:[PBSourceViewGitWorktreeItem revSpecifierForWorktree:worktree]];
	if (!self) return nil;

	_worktree = worktree;

	return self;
}

- (NSString *)title
{
	return [self headDescription];
}

- (NSURL *)URL
{
	return [NSURL fileURLWithPath:self.worktree.path];
}


- (NSString *)iconName
{
	return @"WorktreeBranchTemplate";
}

// This is the row's own text, so a worktree with no branch to name it falls
// back to the directory rather than to the whole path.
- (NSString *)headDescription
{
	if (self.worktree.isBare)
		return NSLocalizedString(@"Bare repository", @"Sidebar row for a bare worktree");

	if (self.worktree.isDetached) {
		NSString *head = self.worktree.HEAD.length > 7 ? [self.worktree.HEAD substringToIndex:7] : self.worktree.HEAD;
		return [NSString stringWithFormat:NSLocalizedString(@"Detached at %@", @"Sidebar row for a detached worktree"), head ?: @"?"];
	}

	NSString *branch = self.worktree.branchRefName;
	if ([branch hasPrefix:@"refs/heads/"])
		branch = [branch substringFromIndex:[@"refs/heads/" length]];

	return branch ?: self.worktree.path.lastPathComponent;
}

- (BOOL)folderIsMissing
{
	return ![[NSFileManager defaultManager] fileExistsAtPath:self.worktree.path];
}

- (BOOL)isUnavailable
{
	return self.worktree.isPrunable || [self folderIsMissing];
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
	else if ([self folderIsMissing])
		[parts addObject:NSLocalizedString(@"Its folder is not there", @"Sidebar tooltip for a worktree whose folder is missing, which git has not reported as prunable")];

	[parts addObject:self.worktree.path];

	return [parts componentsJoinedByString:@"\n"];
}

@end

NS_ASSUME_NONNULL_END
