//
//  PBStashController.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-27.
//  Copyright (c) 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitStash.h"

@class PBGitRepository;

@interface PBStashController : NSObject {
    NSArray *stashes;
@private
    PBGitRepository *repository;
}
@property (nonatomic, retain, readonly) NSArray *stashes;

- (id) initWithRepository:(PBGitRepository *) repo;

- (void) reload;

- (NSArray *) menu;

// actions
- (void) stashLocalChanges;
- (void) clearAllStashes;

@end
