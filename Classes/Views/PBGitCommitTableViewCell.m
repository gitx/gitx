//
//  PBGitCommitTableViewCell.m
//  GitX
//
//  Created by Max Langer on 01.12.17.
//

#import "PBGitCommitTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@implementation PBGitCommitTableViewCell

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
	switch (backgroundStyle) {
		case NSBackgroundStyleDark:
			self.textField.textColor = NSColor.whiteColor;
			break;
		default:
			self.textField.textColor = NSColor.labelColor;
			break;
	}

	[super setBackgroundStyle:backgroundStyle];
}

@end

NS_ASSUME_NONNULL_END
