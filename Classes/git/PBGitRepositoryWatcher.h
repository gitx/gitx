//
//  PBGitRepositoryWatcher.h
//  GitX
//
//  Watches a specified path
//
//  Created by Dave Grijalva on 1/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class PBGitRepository;

@interface PBGitRepositoryWatcher : NSObject

@property (readonly, weak) PBGitRepository *repository;

- (instancetype)initWithRepository:(PBGitRepository *)repository;
- (void)start;
- (void)stop;

// The working tree on disk may have moved.
- (void)noteDiskChanged;

@end

NS_ASSUME_NONNULL_END
