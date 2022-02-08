//
//  PBSidebarList.m
//  GitX
//
//  Created by Max Langer on 05.12.17.
//

#import "PBSidebarList.h"
#import "PBGitSidebarController.h"

NS_ASSUME_NONNULL_BEGIN

@implementation PBSidebarList

- (nullable NSMenu *)menuForEvent:(NSEvent *)event
{
	[super menuForEvent:event];

	NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
	NSInteger row = [self rowAtPoint:point];

	PBGitSidebarController *controller = (PBGitSidebarController *)[self delegate];

	return [controller menuForRow:row];
}

@end

NS_ASSUME_NONNULL_END
