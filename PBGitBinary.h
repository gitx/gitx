//
//  PBGitBinary.h
//  GitX
//
//  Created by Pieter de Bie on 04-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GitX_Prefix.pch"

#define MIN_GIT_VERSION "1.6.0"

// Returns information about the git binary used to execute commands.
@interface PBGitBinary : NSObject {

}

+ (NSString *) path;
+ (NSString *) version;
+ (NSArray *) searchLocations;
+ (NSString *) notFoundError;
@end
