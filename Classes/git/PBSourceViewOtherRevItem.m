//
//  PBSourceViewOtherRevItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBSourceViewOtherRevItem.h"
#import "PBGitRevSpecifier.h"


@implementation PBSourceViewOtherRevItem

+ (instancetype)otherItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	return [[self alloc] initWithTitle:[revSpecifier title] revSpecifier:revSpecifier];
}

- (NSString *)iconName
{
    return @"BranchTemplate";
}

@end
