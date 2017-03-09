//
//  PBGitDefaults.m
//  GitX
//
//  Created by Jeff Mesnil on 19/10/08.
//  Copyright 2008 Jeff Mesnil (http://jmesnil.net/). All rights reserved.
//

#import "PBGitDefaults.h"
#import "PBHistorySearchController.h"

#define kDefaultVerticalLineLength 50
#define kCommitMessageViewVerticalLineLength @"PBCommitMessageViewVerticalLineLength"
#define kDefaultVerticalBodyLineLength 72
#define kCommitMessageViewVerticalBodyLineLength @"PBCommitMessageViewVerticalBodyLineLength"
#define kCommitMessageViewHasVerticalLine @"PBCommitMessageViewHasVerticalLine"
#define kEnableGist @"PBEnableGist"
#define kEnableGravatar @"PBEnableGravatar"
#define kConfirmPublicGists @"PBConfirmPublicGists"
#define kPublicGist @"PBGistPublic"
#define kShowWhitespaceDifferences @"PBShowWhitespaceDifferences"
#define kOpenCurDirOnLaunch @"PBOpenCurDirOnLaunch"
#define kShowOpenPanelOnLaunch @"PBShowOpenPanelOnLaunch"
#define kShouldCheckoutBranch @"PBShouldCheckoutBranch"
#define kRecentCloneDestination @"PBRecentCloneDestination"
#define kShowStageView @"PBShowStageView"
#define kOpenPreviousDocumentsOnLaunch @"PBOpenPreviousDocumentsOnLaunch"
#define kPreviousDocumentPaths @"PBPreviousDocumentPaths"
#define kBranchFilterState @"PBBranchFilter"
#define kHistorySearchMode @"PBHistorySearchMode"
#define kSuppressedDialogWarnings @"Suppressed Dialog Warnings"
#define kUseRepositoryWatcher @"PBUseRepositoryWatcher"
#define kRepositoryHosters @"PBRepositoryHosters"

@implementation PBGitDefaults

#pragma mark Initial Defaults

+ (void)initialize
{
	NSDictionary<NSString *, NSObject*> *defaultValues = @{
	    kCommitMessageViewVerticalLineLength: @(kDefaultVerticalLineLength),
	    kCommitMessageViewVerticalBodyLineLength: @(kDefaultVerticalBodyLineLength),
	    kCommitMessageViewHasVerticalLine: @YES,
	    kEnableGist: @YES,
	    kEnableGravatar: @YES,
	    kConfirmPublicGists: @YES,
	    kPublicGist: @NO,
	    kShowWhitespaceDifferences: @YES,
	    kOpenCurDirOnLaunch: @YES,
	    kShowOpenPanelOnLaunch: @YES,
	    kShouldCheckoutBranch: @YES,
	    kOpenPreviousDocumentsOnLaunch: @NO,
	    kHistorySearchMode: @(PBHistorySearchModeBasic),
	    kUseRepositoryWatcher: @YES,
	    kRepositoryHosters: [self defaultRepositoryHosters]
    };

	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)defaultRepositoryHosters {
	NSURL *plistURL = [[NSBundle mainBundle].resourceURL URLByAppendingPathComponent:@"Hosters.plist"];
	return [NSArray arrayWithContentsOfURL:plistURL];
}


# pragma mark get / set the Preferences

+ (NSInteger) commitMessageViewVerticalLineLength
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:kCommitMessageViewVerticalLineLength];
}

+ (BOOL) commitMessageViewHasVerticalLine
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kCommitMessageViewHasVerticalLine];
}

+ (NSInteger) commitMessageViewVerticalBodyLineLength
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:kCommitMessageViewVerticalBodyLineLength];
}

+ (BOOL) isGistEnabled
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kEnableGist];
}

+ (BOOL) isGravatarEnabled
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kEnableGravatar];
}

+ (BOOL) confirmPublicGists
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kConfirmPublicGists];
}

+ (BOOL) isGistPublic
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kPublicGist];
}

+ (BOOL)showWhitespaceDifferences
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kShowWhitespaceDifferences];
}

+ (BOOL)openCurDirOnLaunch
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kOpenCurDirOnLaunch];
}

+ (BOOL)showOpenPanelOnLaunch
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kShowOpenPanelOnLaunch];
}

+ (BOOL) shouldCheckoutBranch
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kShouldCheckoutBranch];
}

+ (void) setShouldCheckoutBranch:(BOOL)shouldCheckout
{
	[[NSUserDefaults standardUserDefaults] setBool:shouldCheckout forKey:kShouldCheckoutBranch];
}

+ (NSString *) recentCloneDestination
{
	return [[NSUserDefaults standardUserDefaults] stringForKey:kRecentCloneDestination];
}

+ (void) setRecentCloneDestination:(NSString *)path
{
	[[NSUserDefaults standardUserDefaults] setObject:path forKey:kRecentCloneDestination];
}

+ (BOOL) showStageView
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kShowStageView];
}

+ (void) setShowStageView:(BOOL)suppress
{
	return [[NSUserDefaults standardUserDefaults] setBool:suppress forKey:kShowStageView];
}

+ (BOOL) openPreviousDocumentsOnLaunch
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kOpenPreviousDocumentsOnLaunch];
}

+ (void) setPreviousDocumentPaths:(NSArray *)documentPaths
{
	[[NSUserDefaults standardUserDefaults] setObject:documentPaths forKey:kPreviousDocumentPaths];
}

+ (NSArray *) previousDocumentPaths
{
	return [[NSUserDefaults standardUserDefaults] arrayForKey:kPreviousDocumentPaths];
}

+ (void) removePreviousDocumentPaths
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:kPreviousDocumentPaths];
}
+ (NSInteger) branchFilter
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:kBranchFilterState];
}

+ (void) setBranchFilter:(NSInteger)state
{
	[[NSUserDefaults standardUserDefaults] setInteger:state forKey:kBranchFilterState];
}

+ (NSInteger)historySearchMode
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:kHistorySearchMode];
}

+ (void)setHistorySearchMode:(NSInteger)mode
{
	[[NSUserDefaults standardUserDefaults] setInteger:mode forKey:kHistorySearchMode];
}



// Suppressed Dialog Warnings
//
// Represents dialogs where the user has checked the "Do not show this message again" checkbox.
// Keep these together in an array to make it easier to reset all the warnings.

+ (NSSet *)suppressedDialogWarnings
{
	NSSet *suppressedDialogWarnings = [NSSet setWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:kSuppressedDialogWarnings]];
	if (suppressedDialogWarnings == nil)
		suppressedDialogWarnings = [NSSet set];

	return suppressedDialogWarnings;
}

+ (void)suppressDialogWarningForDialog:(NSString *)dialog
{
	NSSet *suppressedDialogWarnings = [[self suppressedDialogWarnings] setByAddingObject:dialog];

	[[NSUserDefaults standardUserDefaults] setObject:[suppressedDialogWarnings allObjects] forKey:kSuppressedDialogWarnings];
}

+ (BOOL)isDialogWarningSuppressedForDialog:(NSString *)dialog
{
	return [[self suppressedDialogWarnings] containsObject:dialog];
}

+ (void)resetAllDialogWarnings
{
	[[NSUserDefaults standardUserDefaults] setObject:nil forKey:kSuppressedDialogWarnings];
	[[NSUserDefaults standardUserDefaults] synchronize];
}


+ (BOOL) useRepositoryWatcher
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kUseRepositoryWatcher];
}


+ (NSArray<NSDictionary<NSString *, NSString *> *> *)hosters
{
	return [[NSUserDefaults standardUserDefaults] objectForKey:kRepositoryHosters];
}

@end
