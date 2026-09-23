//
//  PBGitBinary.h
//  GitX
//
//  Created by Pieter de Bie on 04-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define MIN_GIT_VERSION "1.6.0"
#define PBGitWorktreePruneVersion "2.5"
#define PBGitWorktreeLockVersion "2.10"
#define PBGitWorktreeStateVersion "2.31"

@interface PBGitBinary : NSObject

+ (NSString *)path;
+ (NSString *)version;
+ (NSArray *)searchLocations;
+ (NSString *)notFoundError;

+ (BOOL)version:(NSString *)version isAtLeast:(NSString *)minimum;
+ (NSString *)explanationForVersion:(NSString *)version belowRequired:(NSString *)minimum;
@end
