//
//  PBGitBinary.m
//  GitX
//
//  Created by Pieter de Bie on 04-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitBinary.h"
#import "PBTask.h"

@implementation PBGitBinary

static NSString *gitPath = nil;
static NSString *gitVersion = nil;

NSString *const PBGitBinaryVersionDidChangeNotification = @"PBGitBinaryVersionDidChangeNotification";

+ (NSString *)versionForPath:(NSString *)path
{
	if (!path)
		return nil;

	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
		return nil;

	NSError *error = nil;
	NSString *version = [PBTask outputForCommand:path arguments:@[ @"--version" ] error:&error];
	if (!version)
		NSLog(@"Running '%@ --version' failed: %@", path, error);

	NSString *extracted = [self extractGitVersion:version];
	if (version && !extracted)
		NSLog(@"Could not parse the output of '%@ --version': %@", path, version);

	return extracted;
}

+ (NSString *)extractGitVersion:(NSString *)versionString
{
	NSError *error;
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"git version ([0-9.]+)"
																		   options:0
																			 error:&error];
	if (!versionString)
		return nil;

	NSTextCheckingResult *result = [regex firstMatchInString:versionString
													 options:0
													   range:NSMakeRange(0, versionString.length)];
	if (result != nil && result.numberOfRanges == 2) {
		return [versionString substringWithRange:[result rangeAtIndex:1]];
	}
	return nil;
}

+ (void)takeVersion:(NSString *)version
{
	gitVersion = version;

	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:PBGitBinaryVersionDidChangeNotification object:nil];
	});
}

+ (NSString *)acceptableVersionForPath:(NSString *)path
{
	if (!path)
		return nil;

	NSString *version = [self versionForPath:path];
	if (!version)
		return nil;

	if ([self version:version isAtLeast:@"" MIN_GIT_VERSION])
		return version;

	NSLog(@"Found a git binary at %@, but is only version %@", path, version);
	return nil;
}

+ (BOOL)acceptBinary:(NSString *)path
{
	NSString *version = [self acceptableVersionForPath:path];
	if (!version)
		return NO;

	gitPath = path;
	[self takeVersion:version];
	return YES;
}

+ (void)showInvalidGitPathAlert:(NSString *)path
{
	NSAlert *alert = [[NSAlert alloc] init];

	alert.messageText = NSLocalizedString(@"Invalid git path", @"Error message for NSUserDefaults configured path to git binary that does not point to a git binary");
	alert.informativeText = [NSString stringWithFormat:NSLocalizedString(
														   @"The path „%@“, which is configured as a custom git path in the "
															"preferences window, is not a valid git v" MIN_GIT_VERSION " or higher binary. "
															"Using the default search paths instead.",
														   "Informative text for NSUserDefaults configured path to git binary that does not point to a git binary"),
													   path];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];

	[alert runModal];
}

+ (NSString *)findDefaultBinaryVersion:(NSString **)foundVersion
{
	NSString * (^accepted)(NSString *) = ^NSString *(NSString *candidate) {
		NSString *version = [self acceptableVersionForPath:candidate];
		if (!version)
			return nil;

		*foundVersion = version;
		return candidate;
	};

	// Try to find the path of the Git binary
	char *envPath = getenv("GIT_PATH");
	if (envPath) {
		NSString *found = accepted([NSString stringWithUTF8String:envPath]);
		if (found)
			return found;
	}

	// No explicit path.

	// Try to find git with "which"
	NSString *whichPath = [PBTask outputForCommand:@"/usr/bin/which" arguments:@[ @"git" ] error:NULL];
	NSString *found = accepted(whichPath);
	if (found)
		return found;

	// Still no path. Let's try some default locations.
	for (NSString *location in [PBGitBinary searchLocations]) {
		found = accepted(location);
		if (found)
			return found;
	}

	// Lastly, try `xcrun git`
	NSString *xcrunPath = [PBTask outputForCommand:@"/usr/bin/xcrun" arguments:@[ @"-f", @"git" ] error:NULL];
	found = accepted(xcrunPath);
	if (found)
		return found;

	NSLog(@"Could not find a git binary higher than version " MIN_GIT_VERSION);
	return nil;
}

+ (void)findDefaultBinary
{
	NSString *version = nil;
	NSString *found = [self findDefaultBinaryVersion:&version];
	if (!found)
		return;

	gitPath = found;
	[self takeVersion:version];
}

+ (void)validateConfiguredPath:(NSString *)path
{
	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSString *version = [self acceptableVersionForPath:path];
		if (version) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[self takeVersion:version];
			});
			return;
		}

		NSLog(@"The configured git path %@ failed validation, falling back to the default search", path);
		NSString *fallbackVersion = nil;
		NSString *fallbackPath = [self findDefaultBinaryVersion:&fallbackVersion];

		dispatch_async(dispatch_get_main_queue(), ^{
			if (fallbackPath) {
				NSLog(@"Using the git binary %@ (version %@) instead of %@", fallbackPath, fallbackVersion, path);
				gitPath = fallbackPath;
				[self takeVersion:fallbackVersion];
			}
			[self showInvalidGitPathAlert:path];
		});
	});
}

+ (void)initialize
{
	// Check what we might have in user defaults
	// NOTE: Currently this should NOT have a registered default, or the searching bits below won't work
	gitPath = [[NSUserDefaults standardUserDefaults] stringForKey:@"gitExecutable"];
	if (gitPath.length > 0) {
		if ([[NSFileManager defaultManager] isExecutableFileAtPath:gitPath]) {
			NSLog(@"Using the configured git path %@, validating it in the background", gitPath);
			[self validateConfiguredPath:gitPath];
			return;
		}

		NSLog(@"The configured git path %@ is not an executable file", gitPath);
		[self showInvalidGitPathAlert:gitPath];
	}

	[self findDefaultBinary];
}

+ (NSString *)path;
{
	return gitPath;
}

static NSMutableArray *locations = nil;

+ (NSArray *)searchLocations
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		locations = [[NSMutableArray alloc] initWithObjects:
												@"/opt/homebrew/bin/git",
												@"/opt/local/bin/git",
												@"/sw/bin/git",
												@"/opt/git/bin/git",
												@"/usr/local/bin/git",
												@"/usr/local/git/bin/git",
												nil];

		[locations addObject:[@"~/bin/git" stringByExpandingTildeInPath]];
		[locations addObject:@"/usr/bin/git"];
	});
	return locations;
}

+ (NSString *)notFoundError
{
	NSString *searchPathsString = [[PBGitBinary searchLocations] componentsJoinedByString:@"\n\t"];
	return [NSString stringWithFormat:
						 NSLocalizedString(
							 @"Could not find a git binary version " MIN_GIT_VERSION " or higher.\n"
							 @"Please make sure there is a git binary in one of the following locations:"
							 @"\n\n\t%@",
							 @"Error message when no git client can be found."),
						 searchPathsString];
}


+ (NSString *)version
{
	return gitVersion;
}

+ (BOOL)version:(NSString *)version isAtLeast:(NSString *)minimum
{
	if (!version)
		return NO;

	return [version compare:minimum options:NSNumericSearch] != NSOrderedAscending;
}

+ (NSString *)explanationForVersion:(NSString *)version belowRequired:(NSString *)minimum
{
	if (!version)
		return [NSString stringWithFormat:NSLocalizedString(@"Requires git %@ or later", @"Tooltip for an action the git in use cannot perform, when its version is unknown"), minimum];

	return [NSString stringWithFormat:NSLocalizedString(@"Requires git %@ or later (found %@)", @"Tooltip for an action the git in use is too old to perform"), minimum, version];
}

@end
