//
//  PBSourceViewStageItem.m
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import "PBSourceViewStageItem.h"

@implementation PBSourceViewStageItem

+ (instancetype)stageItem
{
	return [[self alloc] initWithTitle:@"Stage" revSpecifier:nil];
}

- (NSString *)iconName
{
	return @"StageTemplate";
}

@end
