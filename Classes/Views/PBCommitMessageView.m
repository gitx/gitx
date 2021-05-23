//
//  PBCommitMessageView.m
//  GitX
//
//  Created by Jeff Mesnil on 13/10/08.
//  Copyright 2008 Jeff Mesnil (http://jmesnil.net/). All rights reserved.
//

#import "PBCommitMessageView.h"

#import "PBGitDefaults.h"
#import "PBGitRepository.h"
#import "MAKVONotificationCenter.h"

@implementation PBCommitMessageView

- (void)awakeFromNib
{
	[super awakeFromNib];

	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	[defaults addObserver:self
				  keyPath:@[ @"PBCommitMessageViewHasVerticalLine",
							 @"PBCommitMessageViewVerticalLineLength",
							 @"PBCommitMessageViewVerticalBodyLineLength" ]
				  options:NSKeyValueObservingOptionNew
					block:^(MAKVONotification *notification) {
						[self setNeedsDisplay:YES];
					}];
}

- (void)drawRect:(NSRect)aRect
{
	[super drawRect:aRect];

	if ([PBGitDefaults commitMessageViewHasVerticalLine]) {
		CGFloat characterWidth = [@" " sizeWithAttributes:[self typingAttributes]].width;
		CGFloat lineWidth = characterWidth * [PBGitDefaults commitMessageViewVerticalLineLength];
		NSRect line;
		CGFloat padding;
		CGFloat textViewHeight = [self bounds].size.height;

		// draw a vertical line after the given size (used as an indicator
		// for the first line of the commit message)
		[[NSColor lightGrayColor] set];
		padding = [[self textContainer] lineFragmentPadding];
		line.origin.x = padding + lineWidth;
		line.origin.y = 0;
		line.size.width = 1;
		line.size.height = textViewHeight;
		NSRectFill(line);

		// and one for the body of the commit message
		lineWidth = characterWidth * [PBGitDefaults commitMessageViewVerticalBodyLineLength];
		[[NSColor darkGrayColor] set];
		padding = [[self textContainer] lineFragmentPadding];
		line.origin.x = padding + lineWidth;
		line.origin.y = 0;
		line.size.width = 1;
		line.size.height = textViewHeight;
		NSRectFill(line);
	}
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];

	if ([[pboard types] containsObject:NSFilenamesPboardType]) {
		NSArray *filenames = [pboard propertyListForType:NSFilenamesPboardType];
		NSString *baseDir = [self.repository.workingDirectory stringByAppendingString:@"/"];
		if (baseDir) {
			NSMutableArray *relativeNames = [NSMutableArray new];
			for (NSString *filename in filenames) {
				if ([filename hasPrefix:baseDir]) {
					NSString *relativeName = [filename substringFromIndex:(baseDir.length)];
					if (relativeName.length) {
						[relativeNames addObject:relativeName];
						continue;
					}
				}
				[relativeNames addObject:filename];
			}
			[pboard clearContents];
			[pboard writeObjects:relativeNames];
		}
	}
	return [super performDragOperation:sender];
}

@end
