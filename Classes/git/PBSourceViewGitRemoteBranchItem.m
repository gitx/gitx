//
//  PBSourceViewGitRemoteBranchItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBSourceViewGitRemoteBranchItem.h"
#import "PBGitRevSpecifier.h"

@implementation PBSourceViewGitRemoteBranchItem

+ (instancetype)remoteBranchItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	return [[self alloc] initWithTitle:revSpecifier.description.lastPathComponent revSpecifier:revSpecifier];
}

- (NSString *)iconName
{
	return @"RemoteBranchTemplate";
}

@end
