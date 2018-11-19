//
//  PBSourceViewGitRemoteItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBSourceViewGitRemoteItem.h"
#import "PBGitRef.h"


@implementation PBSourceViewGitRemoteItem

+ (instancetype)remoteItemWithTitle:(NSString *)title
{
	return [[self alloc] initWithTitle:title revSpecifier:nil];
}

- (NSString *)iconName
{
    return @"RemoteTemplate";
}

- (PBGitRef *)ref
{
	return [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:self.title]];
}

@end
