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
#define kCommitMessageViewHasVerticalLine @"PBCommitMessageViewHasVerticalLine"
#define kEnableGist @"PBEnableGist"
#define kEnableGravatar @"PBEnableGravatar"
#define kConfirmPublicGists @"PBConfirmPublicGists"
#define kPublicGist @"PBGistPublic"
#define kShowWhitespaceDifferences @"PBShowWhitespaceDifferences"
#define kRefreshAutomatically @"PBRefreshAutomatically"
#define kUseAskPasswd @"PBUseAskPasswd"
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
#define kUseITerm2 @"PBUseITerm2"
#define kITerm2Available @"PBITerm2Available"


@implementation PBGitDefaults

+ (void)initialize
{
	NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
	[defaultValues setObject:[NSNumber numberWithInt:kDefaultVerticalLineLength]
                      forKey:kCommitMessageViewVerticalLineLength];
    [defaultValues setObject:[NSNumber numberWithBool:YES]
                      forKey:kCommitMessageViewHasVerticalLine];
	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:kEnableGist];
	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:kEnableGravatar];
	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:kConfirmPublicGists];
	[defaultValues setObject:[NSNumber numberWithBool:NO]
					  forKey:kPublicGist];
	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:kShowWhitespaceDifferences];
	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:kRefreshAutomatically];
	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:kUseAskPasswd];
	[defaultValues setObject:[NSNumber numberWithBool:NO]
					  forKey:kOpenCurDirOnLaunch];
	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:kShowOpenPanelOnLaunch];
	[defaultValues setObject:[NSNumber numberWithBool:YES]
					  forKey:kShouldCheckoutBranch];
	[defaultValues setObject:[NSNumber numberWithBool:NO]
                      forKey:kOpenPreviousDocumentsOnLaunch];
	[defaultValues setObject:[NSNumber numberWithInteger:kGitXBasicSeachMode]
                      forKey:kHistorySearchMode];
	[defaultValues setObject:[NSNumber numberWithBool:NO]
					  forKey:kUseITerm2];
	[defaultValues setObject:[NSNumber numberWithBool:NO]
					  forKey:kITerm2Available];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
}

+ (int) commitMessageViewVerticalLineLength
{
	return [[NSUserDefaults standardUserDefaults] integerForKey:kCommitMessageViewVerticalLineLength];
}

+ (BOOL) commitMessageViewHasVerticalLine
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kCommitMessageViewHasVerticalLine];
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

+ (BOOL) showWhitespaceDifferences
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kShowWhitespaceDifferences];
}
							  
+ (BOOL) refreshAutomatically
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kRefreshAutomatically];
}

+ (BOOL) useAskPasswd
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kUseAskPasswd];
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

+ (BOOL) isUseITerm2
{
	[self isITerm2Available];
	return [[NSUserDefaults standardUserDefaults] boolForKey:kUseITerm2];
}

+ (BOOL) isITerm2Available 
{
	NSString *iTermPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.googlecode.iterm2"];
	[self setITerm2Available:[[NSFileManager defaultManager] fileExistsAtPath:iTermPath]];
	
	return [[NSUserDefaults standardUserDefaults] boolForKey:kITerm2Available];
}

+ (void) setITerm2Available:(BOOL)iTerm2Available 
{
	if (!iTerm2Available)
		[[NSUserDefaults standardUserDefaults] setBool:iTerm2Available forKey:kUseITerm2];
	
	[[NSUserDefaults standardUserDefaults] setBool:iTerm2Available forKey:kITerm2Available];
	[[NSUserDefaults standardUserDefaults] synchronize];
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


@end
