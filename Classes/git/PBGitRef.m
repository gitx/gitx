//
//  PBGitRef.m
//  GitX
//
//  Created by Pieter de Bie on 06-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRef.h"


NSString *const kGitXTagType = @"tag";
NSString *const kGitXBranchType = @"branch";
NSString *const kGitXRemoteType = @"remote";
NSString *const kGitXRemoteBranchType = @"remote branch";
NSString *const kGitXStashType = @"stash";

NSString *const kGitXTagRefPrefix = @"refs/tags/";
NSString *const kGitXBranchRefPrefix = @"refs/heads/";
NSString *const kGitXRemoteRefPrefix = @"refs/remotes/";
NSString *const kGitXStashRefPrefix = @"refs/stash@";

@interface PBGitRef ()

@property (nonatomic, strong) NSString *ref;

@end

@implementation PBGitRef

+ (instancetype)refFromString:(NSString *)s
{
	return [[PBGitRef alloc] initWithString:s];
}

- (instancetype)initWithString:(NSString *)s
{
	self = [super init];
	if (!self) return nil;

	_ref = s;
	return self;
}

- (NSString *)debugDescription
{
	return [NSString stringWithFormat:@"<%@: %p ref: %@", NSStringFromClass([self class]), self, self.ref];
}

- (NSString *)tagName
{
	if (![self isTag])
		return nil;

	return [self shortName];
}

- (NSString *)branchName
{
	if (![self isBranch])
		return nil;

	return [self shortName];
}

- (NSString *)remoteName
{
	if (![self isRemote])
		return nil;

	return (NSString *)[[self.ref componentsSeparatedByString:@"/"] objectAtIndex:2];
}

- (NSString *)remoteBranchName
{
	if (![self isRemoteBranch])
		return nil;

	return [[self shortName] substringFromIndex:[[self remoteName] length] + 1];
	;
}

- (NSString *)type
{
	if ([self isBranch])
		return @"head";
	if ([self isTag])
		return @"tag";
	if ([self isRemote])
		return @"remote";
	if ([self isStash])
		return @"stash";
	return nil;
}

- (BOOL)isBranch
{
	return [self.ref hasPrefix:kGitXBranchRefPrefix];
}

- (BOOL)isTag
{
	return [self.ref hasPrefix:kGitXTagRefPrefix];
}

- (BOOL)isRemote
{
	return [self.ref hasPrefix:kGitXRemoteRefPrefix];
}

- (BOOL)isRemoteBranch
{
	if (![self isRemote])
		return NO;

	return ([[self.ref componentsSeparatedByString:@"/"] count] > 3);
}

- (BOOL)isStash
{
	return [self.ref hasPrefix:kGitXStashRefPrefix];
}

- (BOOL)isEqualToRef:(PBGitRef *)otherRef
{
	return [self.ref isEqualToString:[otherRef ref]];
}

- (PBGitRef *)remoteRef
{
	if (![self isRemote])
		return nil;

	return [PBGitRef refFromString:[kGitXRemoteRefPrefix stringByAppendingString:[self remoteName]]];
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	return NO;
}

+ (BOOL)isKeyExcludedFromWebScript:(const char *)name
{
	return NO;
}


#pragma mark <PBGitRefish>

- (NSString *)refishName
{
	return self.ref;
}

- (NSString *)shortName
{
	if ([self isStash])
		return [self.ref substringFromIndex:5];
	if ([self type])
		return [self.ref substringFromIndex:[[self type] length] + 7];
	return self.ref;
}

- (NSString *)refishType
{
	if ([self isBranch])
		return kGitXBranchType;
	if ([self isTag])
		return kGitXTagType;
	if ([self isRemoteBranch])
		return kGitXRemoteBranchType;
	if ([self isRemote])
		return kGitXRemoteType;
	if ([self isStash])
		return kGitXStashType;
	return nil;
}

@end
