//
//  PBGitDefaults.h
//  GitX
//
//  Created by Jeff Mesnil on 19/10/08.
//  Copyright 2008 Jeff Mesnil (http://jmesnil.net/). All rights reserved.
//

#define kDialogAcceptDroppedRef @"Accept Dropped Ref"
#define kDialogConfirmPush @"Confirm Push"
#define kDialogDeleteRef @"Delete Ref"
#define kDialogForcePushWithLease @"Force Push With Lease"
#define kDialogStashDrop @"Stash Drop"

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

@interface PBDialogWarning : NSObject

@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *detail;

@end

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


// The store for the dialog warnings and the remembered Preferences tab. Tests give
// it a store of their own so they leave the user's settings alone; nil restores it.
+ (NSUserDefaults *)userDefaults;
+ (void)useUserDefaults:(nullable NSUserDefaults *)defaults;

// Suppressed Dialog Warnings
+ (NSArray<PBDialogWarning *> *)dialogWarnings;
+ (void)suppressDialogWarningForDialog:(NSString *)dialog;
+ (void)unsuppressDialogWarningForDialog:(NSString *)dialog;
+ (BOOL)isDialogWarningSuppressedForDialog:(NSString *)dialog;
+ (void)resetAllDialogWarnings;

@end
