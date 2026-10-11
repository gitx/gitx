//
//  PBGitBinary.h
//  GitX
//
//  Created by Pieter de Bie on 04-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define MIN_GIT_VERSION "1.6.0"
#define PBGitWorktreeAddVersion "2.5"
#define PBGitWorktreePruneVersion "2.5"
#define PBGitWorktreeLockVersion "2.10"
#define PBGitWorktreeRemoveVersion "2.17"
#define PBGitWorktreeRepairVersion "2.29"
#define PBGitWorktreeStateVersion "2.31"
#define PBGitWorktreeLinkStyleVersion "2.48"

// Posted on the main queue once the version of the git in use is known or changes.
extern NSString *const PBGitBinaryVersionDidChangeNotification;

@interface PBGitBinary : NSObject

+ (NSString *)path;
+ (NSString *)version;
+ (NSArray *)searchLocations;
+ (NSString *)notFoundError;

+ (BOOL)version:(NSString *)version isAtLeast:(NSString *)minimum;
+ (NSString *)explanationForVersion:(NSString *)version belowRequired:(NSString *)minimum;
@end
