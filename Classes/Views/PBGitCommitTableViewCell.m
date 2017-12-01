//
//  PBGitCommitTableViewCell.m
//  GitX
//
//  Created by Max Langer on 01.12.17.
//

#import "PBGitCommitTableViewCell.h"

@implementation PBGitCommitTableViewCell

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle {
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
