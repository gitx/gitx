//
//  PBGitRef.h
//  GitX
//
//  Created by Pieter de Bie on 06-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRefish.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kGitXTagType;
extern NSString * const kGitXBranchType;
extern NSString * const kGitXRemoteType;
extern NSString * const kGitXRemoteBranchType;
extern NSString * const kGitXStashType;

extern NSString * const kGitXTagRefPrefix;
extern NSString * const kGitXBranchRefPrefix;
extern NSString * const kGitXRemoteRefPrefix;
extern NSString * const kGitXStashRefPrefix;

@interface PBGitRef : NSObject <PBGitRefish>

+ (instancetype)refFromString:(NSString *)s;
- (instancetype)initWithString:(NSString *)s;


@property (nullable, readonly) NSString *tagName;
@property (nullable, readonly) NSString *branchName;
@property (nullable, readonly) NSString *remoteName;
@property (nullable, readonly) NSString *remoteBranchName;

@property (nullable, readonly) NSString *type;

@property (readonly, getter=isBranch) BOOL branch;
@property (readonly, getter=isTag) BOOL tag;
@property (readonly, getter=isRemote) BOOL remote;
@property (readonly, getter=isRemoteBranch) BOOL remoteBranch;
@property (readonly, getter=isStash) BOOL stash;

- (nullable PBGitRef *)remoteRef;

- (BOOL)isEqualToRef:(PBGitRef *)otherRef;

@property(nonatomic, strong, readonly) NSString *ref;

@end

NS_ASSUME_NONNULL_END
