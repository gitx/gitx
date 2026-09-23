//
//  PBGitDefaults.h
//  GitX
//
//  Created by Jeff Mesnil on 19/10/08.
//  Copyright 2008 Jeff Mesnil (http://jmesnil.net/). All rights reserved.
//

#define kDialogAcceptDroppedRef @"Accept Dropped Ref"

typedef NS_ENUM(NSInteger, PBPruneOnFetchSetting) {
	PBPruneOnFetchUseGitConfig = 0,
	PBPruneOnFetchAlways = 1,
	PBPruneOnFetchNever = 2,
};

typedef NS_ENUM(NSInteger, PBAppearanceSetting) {
	PBAppearanceSystem = 0,
	PBAppearanceLight = 1,
	PBAppearanceDark = 2,
};

typedef NS_ENUM(NSInteger, PBCommitDateFormatSetting) {
	PBCommitDateFormatShort = 0,
	PBCommitDateFormatMedium = 1,
	PBCommitDateFormatLong = 2,
	PBCommitDateFormatCustom = 3,
};

@interface PBGitDefaults : NSObject {
}

+ (NSInteger)commitMessageViewVerticalLineLength;
+ (NSInteger)commitMessageViewVerticalBodyLineLength;
+ (BOOL)commitMessageViewHasVerticalLine;
+ (BOOL)isGistEnabled;
+ (BOOL)isGravatarEnabled;
+ (BOOL)confirmPublicGists;
+ (BOOL)isGistPublic;
+ (BOOL)showWhitespaceDifferences;
+ (BOOL)shouldCheckoutBranch;
+ (void)setShouldCheckoutBranch:(BOOL)shouldCheckout;
+ (NSString *)recentCloneDestination;
+ (void)setRecentCloneDestination:(NSString *)path;
+ (BOOL)showStageView;
+ (void)setShowStageView:(BOOL)suppress;
+ (NSInteger)branchFilter;
+ (void)setBranchFilter:(NSInteger)state;
+ (NSInteger)historySearchMode;
+ (void)setHistorySearchMode:(NSInteger)mode;
+ (BOOL)useRepositoryWatcher;
+ (PBPruneOnFetchSetting)pruneOnFetch;
+ (NSString *)terminalHandler;
+ (void)setTerminalHandler:(NSString *)bundleIdentifier;
+ (BOOL)terminalOpenAsTab;
+ (void)setTerminalOpenAsTab:(BOOL)openAsTab;
+ (PBAppearanceSetting)appearance;
+ (void)setAppearance:(PBAppearanceSetting)appearance;
+ (PBCommitDateFormatSetting)commitDateFormat;
+ (NSString *)commitDateCustomFormat;


// Suppressed Dialog Warnings
+ (void)suppressDialogWarningForDialog:(NSString *)dialog;
+ (BOOL)isDialogWarningSuppressedForDialog:(NSString *)dialog;
+ (void)resetAllDialogWarnings;

@end
