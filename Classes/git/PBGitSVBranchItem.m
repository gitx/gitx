//
//  PBGitSVBranchItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBSourceViewGitBranchItem.h"
#import "PBGitRevSpecifier.h"

@implementation PBSourceViewGitBranchItem

+ (instancetype)branchItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	return [[self alloc] initWithTitle:[[revSpecifier description] lastPathComponent] revSpecifier:revSpecifier];
}

- (NSString *)iconName
{
    return @"BranchTemplate";
}

@end
