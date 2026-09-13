//
//  PBSidebarTableViewCell.m
//  GitX
//
//  Created by Max Langer on 02.12.17.
//

#import "PBSidebarTableViewCell.h"
#import "PBSourceViewBadge.h"
#import "PBGitSidebarController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation PBSidebarTableViewCell

#pragma mark context menu delegate methods

- (void)setIsCheckedOut:(BOOL)isCheckedOut
{
	_isCheckedOut = isCheckedOut;
	[self updateCheckmarkImage];
}

- (void)setWorktreePath:(nullable NSString *)worktreePath
{
	_worktreePath = [worktreePath copy];
	[self updateCheckmarkImage];
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
	[super setBackgroundStyle:backgroundStyle];
	[self updateCheckmarkImage];
}

- (void)updateCheckmarkImage
{
	if (_isCheckedOut) {
		// We hand over the textField cell because the badge derives its drawing style from that.
		// Maybe we should replace this custom drawing with an static template image ..
		[checkedOutImageView setImage:[PBSourceViewBadge checkedOutBadgeForCell:self]];
	} else {
		[checkedOutImageView setImage:nil];
	}

	[checkedOutImageView setHidden:!_isCheckedOut];

	self.toolTip = _worktreePath.length ? [NSString stringWithFormat:NSLocalizedString(@"Checked out in the worktree at %@", @"Sidebar tooltip for a branch held by another worktree"), _worktreePath] : nil;
}

@end

NS_ASSUME_NONNULL_END
