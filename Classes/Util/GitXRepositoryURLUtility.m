//
//  GitXRepositoryWebUtility.m
//  GitX
//
//  Created by Sven on 02.03.17.
//
//

#import "GitXRepositoryURLUtility.h"
#import "PBGitRepository.h"
#import "PBGitRef.h"
#import "PBGitDefaults.h"

#define kRepositoryDerivedURL @"derivedURL"

@implementation GitXRepositoryURLUtility

#pragma mark Tools


+ (NSURL * _Nullable) remoteURLForRef:(PBGitRef * _Nonnull)ref
							   inRepo:(PBGitRepository * _Nonnull)repo
{
	return (NSURL *)[self remoteURLInfoForRef:ref inRepo:repo][kRepositoryDerivedURL];
}


+ (NSString * _Nullable) remoteHosterDisplayNameForRef:(PBGitRef * _Nonnull)ref
												inRepo:(PBGitRepository * _Nonnull)repo
{
	return (NSString *)[self remoteURLInfoForRef:ref inRepo:repo][kRepositoryHosterDisplayName];
}


+ (BOOL) hasRemoteURL:(PBGitRef * _Nonnull)ref
			   inRepo:(PBGitRepository * _Nonnull)repo
{
	return [self remoteURLInfoForRef:ref inRepo:repo] != nil;
}



#pragma mark private implementation

+ (NSDictionary<NSString *, NSObject *> * _Nullable) remoteURLInfoForRef:(PBGitRef * _Nonnull)ref
																  inRepo:(PBGitRepository * _Nonnull)repo
{
	NSString * remoteName = ref.remoteName;

	NSError * error;
	GTRemote * remote = [GTRemote remoteWithName:remoteName inRepository:repo.gtRepo error:&error];
	if (remote == nil) {
		NSLog(@"Could not find Remote for ref %@ (this should not happen): %@", ref, error);
		return nil;
	}

	NSString * URLString = remote.URLString;
	if (URLString == nil) {
		return nil;
	}

	// If the remote is at a path, see whether it is available locally and use a file:/// URL
	NSString * absolutePath = URLString.stringByExpandingTildeInPath.stringByStandardizingPath;
	if ([[NSFileManager defaultManager] fileExistsAtPath:absolutePath]) {
		NSURL * URL = [NSURL fileURLWithPath:absolutePath];
		return @{
				 kRepositoryHosterDisplayName: NSLocalizedString(@"in Finder", @"String to indicate the Repository will be opened in the macOS Finder"),
				 kRepositoryDerivedURL: URL.URLByDeletingLastPathComponent
				 };
	}

	// We have a Web URL.
	return [self gitURLToWebURL:URLString];
}


/**
 * Using NSString instead of NSURL here because SSH connection »URLs«
 * are only considered paths by NSURL.
 */
+ (NSDictionary<NSString *, NSObject *> * _Nullable) gitURLToWebURL:(NSString * _Nonnull)gitURLString
{
	for (NSDictionary<NSString *, NSString *> *hoster in [PBGitDefaults hosters]) {
		NSString * displayString = hoster[kRepositoryHosterDisplayName];
		NSString * regexString = hoster[kRepositoryHosterRegex];
		NSString * URLFormat = hoster[kRepositoryHosterURLFormat];
		if (displayString == nil || regexString == nil || URLFormat == nil) {
			NSLog(@"Hoster information “%@” incomplete.", hoster);
			continue;
		}

		NSError * error;
		NSRegularExpression *regex =
			[NSRegularExpression regularExpressionWithPattern:regexString
													  options:0
														error:&error];
		if (regex == nil) {
			NSLog(@"Invalid Regex “%@” configured for hoster %@", displayString, hoster);
			continue;
		}

		NSString * URLString = [regex stringByReplacingMatchesInString:gitURLString
															   options:0
																 range:NSMakeRange(0, gitURLString.length)
														  withTemplate:URLFormat];

		if ([gitURLString isEqualToString:URLString]) {
			// no match found: try next
			continue;
		}

		NSURL * hosterURL = [NSURL URLWithString:URLString];
		if (hosterURL != nil) {
			NSLog(@"%@ -> %@", gitURLString, hosterURL);
			return @{
					 kRepositoryHosterDisplayName: displayString,
					 kRepositoryDerivedURL: hosterURL
					 };
		}
		else {
			NSLog(@"URL-String “%@” for hosted repository is not a valid URL. %@", URLString, hoster);
		}
	}
	return nil;
}


@end
