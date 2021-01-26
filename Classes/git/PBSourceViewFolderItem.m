//
//  PBSourceViewFolderItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBSourceViewFolderItem.h"


@implementation PBSourceViewFolderItem

+ (instancetype)folderItemWithTitle:(NSString *)title
{
	return [self itemWithTitle:title];
}

- (NSString *)iconName
{
	return self.isExpanded ? @"FolderTemplate" : @"FolderClosedTemplate";
}

@end
