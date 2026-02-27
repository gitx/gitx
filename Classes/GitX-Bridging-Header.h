//
//  GitX-Bridging-Header.h
//  GitX
//
//  Exposes Objective-C headers to Swift.
//  External/ is intentionally excluded – those libs stay in pure ObjC.
//

// ── Cocoa / system ──────────────────────────────────────────────────────────
#import <Cocoa/Cocoa.h>

// ── External frameworks (headers only, no conversion) ───────────────────────
#import <ObjectiveGit/ObjectiveGit.h>
#import "MAKVONotificationCenter.h"

// ── App-level helpers ────────────────────────────────────────────────────────
#import "NSAppearance+PBDarkMode.h"
#import "NSColor+RGB.h"
#import "NSSplitView+GitX.h"
#import "PBMacros.h"

// ── Model / git layer ────────────────────────────────────────────────────────
#import "PBChangedFile.h"
#import "PBCommitList.h"
#import "PBGraphCellInfo.h"
#import "PBSidebarList.h"
#import "PBCLIProxy.h"
#import "GitXRelativeDateFormatter.h"
#import "GitXScriptingConstants.h"
#import "PBNSURLPathUserDefaultsTransfomer.h"

// ── git/ ─────────────────────────────────────────────────────────────────────
#import "PBGitBinary.h"
#import "PBGitCommit.h"
#import "PBGitDefaults.h"
#import "PBGitGraphLine.h"
#import "PBGitGrapher.h"
#import "PBGitHistoryGrapher.h"
#import "PBGitHistoryList.h"
#import "PBGitIndex.h"
#import "PBGitLane.h"
#import "PBGitRef.h"
#import "PBGitRefish.h"
#import "PBGitRepository.h"
#import "PBGitRepositoryWatcher.h"
#import "PBGitRepository_PBGitBinarySupport.h"
#import "PBGitRevList.h"
#import "PBGitRevSpecifier.h"
#import "PBGitStash.h"
#import "PBGitTree.h"
#import "PBGitXProtocol.h"
#import "PBRepositoryFinder.h"
#import "GTOID+JavaScript.h"
#import "PBSourceViewFolderItem.h"
#import "PBSourceViewGitBranchItem.h"
#import "PBSourceViewGitRemoteBranchItem.h"
#import "PBSourceViewGitRemoteItem.h"
#import "PBSourceViewGitStashItem.h"
#import "PBSourceViewGitSubmoduleItem.h"
#import "PBSourceViewGitTagItem.h"
#import "PBSourceViewOtherRevItem.h"
#import "PBSourceViewStageItem.h"

// ── Controllers ───────────────────────────────────────────────────────────────
#import "ApplicationController.h"
#import "DBPrefsWindowController.h"
#import "OpenRecentController.h"
#import "PBDiffWindowController.h"
#import "PBGitCommitController.h"
#import "PBGitHistoryController.h"
#import "PBGitRepositoryDocument.h"
#import "PBGitSidebarController.h"
#import "PBGitWindowController.h"
#import "PBHistorySearchController.h"
#import "PBHistorySearchMode.h"
#import "PBOpenShallowRepositoryErrorRecoveryAttempter.h"
#import "PBPrefsWindowController.h"
#import "PBRepositoryDocumentController.h"
#import "PBServicesController.h"
#import "PBViewController.h"
#import "PBWebChangesController.h"
#import "PBWebController.h"
#import "PBWebDiffController.h"
#import "PBWebHistoryController.h"

// ── Views ─────────────────────────────────────────────────────────────────────
#import "GLFileView.h"
#import "GitXTextView.h"
#import "PBAddRemoteSheet.h"
#import "PBCloneRepositoryPanel.h"
#import "PBCommitHookFailedSheet.h"
#import "PBCommitMessageView.h"
#import "PBCreateBranchSheet.h"
#import "PBCreateTagSheet.h"
#import "PBFileChangesTableView.h"
#import "PBGitCommitTableViewCell.h"
#import "PBGitGradientBarView.h"
#import "PBGitRevisionCell.h"
#import "PBGitRevisionRow.h"
#import "PBGitXMessageSheet.h"
#import "PBQLOutlineView.h"
#import "PBQLTextView.h"
#import "PBRemoteProgressSheet.h"
#import "PBSidebarTableViewCell.h"
#import "PBSourceViewBadge.h"
#import "PBSourceViewItem.h"
#import "PBSourceViewItems.h"
#import "PBUnsortableTableHeader.h"

// ── Util ──────────────────────────────────────────────────────────────────────
#import "GitXCommitCopier.h"
#import "NSApplication+GitXScripting.h"
#import "NSFileHandleExt.h"
#import "NSOutlineViewExt.h"
#import "NSString_Truncate.h"
#import "ObjectiveGit+PBCategories.h"
#import "PBEasyFS.h"
#import "PBError.h"
#import "PBTask.h"
#import "PBTerminalUtil.h"
#import "RJModalRepoSheet.h"

