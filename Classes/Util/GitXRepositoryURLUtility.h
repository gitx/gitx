//
//  GitXRepositoryWebUtility.h
//  GitX
//
//  Created by Sven on 02.03.17.
//
//

#import <Foundation/Foundation.h>

@class PBGitRef;
@class PBGitRepository;

@interface GitXRepositoryURLUtility : NSObject

+ (NSURL * _Nullable) remoteURLForRef:(PBGitRef * _Nonnull)ref
                               inRepo:(PBGitRepository * _Nonnull)repo;

+ (NSString * _Nullable) remoteHosterDisplayNameForRef:(PBGitRef * _Nonnull)ref
												inRepo:(PBGitRepository * _Nonnull)repo;


+ (BOOL) hasRemoteURL:(PBGitRef * _Nonnull)ref
               inRepo:(PBGitRepository * _Nonnull)repo;

@end
