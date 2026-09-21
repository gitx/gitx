//
//  PBGitSidebarWorktreeGroupTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"
#import "PBGitWorktree.h"
#import "PBGitRef.h"
#import "PBGitWindowController.h"
#import "PBGitSidebarController.h"
#import "PBSourceViewItem.h"
#import "PBSourceViewGitWorktreeItem.h"
#import "PBGitDefaults.h"
#import "PBGitRevSpecifier.h"

// Every other worktree test reads a fixed string, so none of them would notice
// git changing what it prints. This one runs git and reads what comes back.
@interface PBGitRepository (WorktreeGroupTesting)
- (void)reloadWorktreePaths;
@end

@interface PBWorktreeStubWindowController : PBGitWindowController
@property (nonatomic, strong) PBGitRepository *stubRepository;
@end

@implementation PBWorktreeStubWindowController

- (PBGitRepository *)repository
{
	return self.stubRepository;
}

@end

@interface PBGitSidebarWorktreeGroupTests : XCTestCase
@property (nonatomic, strong) NSURL *repositoryURL;
@property (nonatomic, strong) NSURL *secondWorktreeURL;
@property (nonatomic, strong) PBGitRepository *repository;
@property (nonatomic, strong) id settingToPutBack;
@end

@implementation PBGitSidebarWorktreeGroupTests

- (void)runGit:(NSArray<NSString *> *)arguments in:(NSURL *)directory
{
	NSTask *task = [[NSTask alloc] init];
	task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/git"];
	task.currentDirectoryURL = directory;
	task.arguments = arguments;
	task.environment = @{@"GIT_AUTHOR_NAME" : @"t", @"GIT_AUTHOR_EMAIL" : @"t@t",
						 @"GIT_COMMITTER_NAME" : @"t", @"GIT_COMMITTER_EMAIL" : @"t@t",
						 @"PATH" : @"/usr/bin:/bin",
						 @"GIT_CONFIG_GLOBAL" : @"/dev/null",
						 @"GIT_CONFIG_SYSTEM" : @"/dev/null"};

	NSError *error = nil;
	if (![task launchAndReturnError:&error]) {
		XCTFail(@"git %@ did not start: %@", arguments.firstObject, error);
		return;
	}

	[task waitUntilExit];
	XCTAssertEqual(task.terminationStatus, 0, @"git %@ failed, so the repository is not the one this test describes", arguments);
}

- (void)setUp
{
	[super setUp];

	// The window loads a nib only for the view it shows, so a GitX left on the
	// stage view would leave the sidebar's history controller nil here.
	self.settingToPutBack = [[NSUserDefaults standardUserDefaults] objectForKey:@"PBShowStageView"];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PBShowStageView"];

	NSURL *root = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
	[[NSFileManager defaultManager] createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:NULL];

	self.repositoryURL = [root URLByAppendingPathComponent:@"main"];
	self.secondWorktreeURL = [root URLByAppendingPathComponent:@"second"];
	[[NSFileManager defaultManager] createDirectoryAtURL:self.repositoryURL withIntermediateDirectories:YES attributes:nil error:NULL];

	[self runGit:@[ @"init", @"-q" ] in:self.repositoryURL];
	[self runGit:@[ @"symbolic-ref", @"HEAD", @"refs/heads/branch_one" ] in:self.repositoryURL];
	[self runGit:@[ @"commit", @"-q", @"--allow-empty", @"-m", @"root" ] in:self.repositoryURL];
	[self runGit:@[ @"worktree", @"add", @"-q", self.secondWorktreeURL.path, @"-b", @"parked" ] in:self.repositoryURL];
	[self runGit:@[ @"worktree", @"lock", @"--reason", @"on an external disk", self.secondWorktreeURL.path ] in:self.repositoryURL];

	NSError *error = nil;
	self.repository = [[PBGitRepository alloc] initWithURL:self.repositoryURL error:&error];
	XCTAssertNotNil(self.repository, @"%@", error);
}

- (void)tearDown
{
	if (self.settingToPutBack)
		[[NSUserDefaults standardUserDefaults] setObject:self.settingToPutBack forKey:@"PBShowStageView"];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PBShowStageView"];

	// The lock has to come off, or the directory outlives the test.
	[self runGit:@[ @"worktree", @"unlock", self.secondWorktreeURL.path ] in:self.repositoryURL];
	[[NSFileManager defaultManager] removeItemAtURL:[self.repositoryURL URLByDeletingLastPathComponent] error:NULL];

	[super tearDown];
}

- (void)waitForTheWorktreeLookup
{
	[self.repository reloadWorktreePaths];

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:10];
	while (self.repository.worktrees.count < 2 && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

- (PBGitWorktree *)worktreeNamed:(NSString *)name
{
	for (PBGitWorktree *worktree in self.repository.worktrees)
		if ([worktree.path.lastPathComponent isEqualToString:name])
			return worktree;

	return nil;
}

- (void)testGitsOwnOutputIsReadIntoTheModel
{
	[self waitForTheWorktreeLookup];

	XCTAssertEqual(self.repository.worktrees.count, 2u, @"%@", self.repository.worktrees);

	PBGitWorktree *main = [self worktreeNamed:@"main"];
	XCTAssertEqualObjects(main.branchRefName, @"refs/heads/branch_one");
	XCTAssertTrue(main.isCurrent, @"the worktree the window has open is the current one");
	XCTAssertFalse(main.isLocked);

	PBGitWorktree *second = [self worktreeNamed:@"second"];
	XCTAssertEqualObjects(second.branchRefName, @"refs/heads/parked");
	XCTAssertFalse(second.isCurrent);
	XCTAssertTrue(second.isLocked, @"this worktree was locked with git itself");
	XCTAssertEqualObjects(second.lockReason, @"on an external disk");
}

- (void)testTheCheapLookupStillAnswersForABranchHeldElsewhere
{
	[self waitForTheWorktreeLookup];

	// git prints the resolved path, and the temporary directory is reached
	// through a symlink, so neither side can be compared as it stands.
	XCTAssertEqualObjects([[self.repository pathOfWorktreeHoldingRef:[PBGitRef refFromString:@"refs/heads/parked"]] stringByStandardizingPath],
						  self.secondWorktreeURL.path.stringByStandardizingPath,
						  @"the dictionary the drawing path reads is derived from the same snapshot");
	XCTAssertNil([self.repository pathOfWorktreeHoldingRef:[PBGitRef refFromString:@"refs/heads/branch_one"]],
				 @"our own branch is not held somewhere else");
}

// +groupItemWithTitle: uppercases what it is given, so a group answers to
// WORKTREES rather than to the name the controller passed.
- (PBSourceViewItem *)groupOfSidebar:(PBGitSidebarController *)sidebar titled:(NSString *)title
{
	for (PBSourceViewItem *item in sidebar.items)
		if ([item.title caseInsensitiveCompare:title] == NSOrderedSame)
			return item;

	return nil;
}

- (PBSourceViewItem *)worktreeGroupOfSidebar:(PBGitSidebarController *)sidebar
{
	return [self groupOfSidebar:sidebar titled:@"Worktrees"];
}

- (void)testTheSidebarListsTheOtherWorktreesAndLeavesOutTheOneWeHaveOpen
{
	PBWorktreeStubWindowController *windowController = [[PBWorktreeStubWindowController alloc] init];
	windowController.stubRepository = self.repository;
	XCTAssertNotNil(windowController.window, @"asking for the window is what loads the sidebar");

	[self waitForTheWorktreeLookup];

	PBGitSidebarController *sidebar = windowController.sidebarViewController;
	XCTAssertNotNil(sidebar, @"the window did not build a sidebar, so nothing below this means anything");

	PBSourceViewItem *group = [self worktreeGroupOfSidebar:sidebar];
	XCTAssertNotNil(group, @"the sidebar has no WORKTREES group, it has %@",
					[sidebar.items valueForKey:@"title"]);

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:10];
	while (group.sortedChildren.count < 1 && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	NSMutableDictionary<NSString *, PBSourceViewGitWorktreeItem *> *rows = [NSMutableDictionary dictionary];
	for (PBSourceViewGitWorktreeItem *row in group.sortedChildren)
		rows[row.title] = row;

	XCTAssertEqual(rows.count, 1u, @"%@", rows.allKeys);
	XCTAssertNil(rows[@"main"], @"the worktree this window has open is already marked in BRANCHES");
	XCTAssertFalse(rows[@"parked"].worktree.isCurrent);
	XCTAssertTrue([rows[@"parked"].statusDescription containsString:@"on an external disk"],
				  @"a locked worktree has to say why: %@", rows[@"parked"].statusDescription);
	XCTAssertEqual(self.repository.worktrees.count, 2u, @"the model still holds every worktree git reports");

	[windowController close];
}

// The group having the rows is not the same as the sidebar showing them: the
// outline view keeps its own expansion state, and a group that was empty when
// the sidebar was built stays collapsed unless it is expanded after the reload.
- (void)testTheWorktreeGroupIsExpandedSoItsRowsAreOnScreen
{
	PBWorktreeStubWindowController *windowController = [[PBWorktreeStubWindowController alloc] init];
	windowController.stubRepository = self.repository;
	XCTAssertNotNil(windowController.window, @"asking for the window is what loads the sidebar");

	[self waitForTheWorktreeLookup];

	PBGitSidebarController *sidebar = windowController.sidebarViewController;
	PBSourceViewItem *group = [self worktreeGroupOfSidebar:sidebar];
	XCTAssertNotNil(group, @"the sidebar has no WORKTREES group");

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:10];
	while (group.sortedChildren.count < 1 && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	NSOutlineView *sourceView = sidebar.sourceView;
	XCTAssertTrue([sourceView isExpandable:group], @"the outline view does not see the %lu worktrees the group holds",
				  (unsigned long)group.sortedChildren.count);
	XCTAssertTrue([sourceView isItemExpanded:group], @"the group is collapsed, so its worktrees are off screen");
	XCTAssertNotEqual([sourceView rowForItem:group.sortedChildren.firstObject], -1,
					  @"the first worktree has no row in the sidebar");

	[windowController close];
}

- (PBSourceViewItem *)worktreeGroupOnceFilledFor:(PBGitSidebarController *)sidebar
{
	PBSourceViewItem *group = [self worktreeGroupOfSidebar:sidebar];

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:10];
	while (group.sortedChildren.count < 1 && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	return group;
}

- (void)testTheWorktreeRowIsLabelledByItsBranchNotItsFolder
{
	PBWorktreeStubWindowController *windowController = [[PBWorktreeStubWindowController alloc] init];
	windowController.stubRepository = self.repository;
	XCTAssertNotNil(windowController.window, @"asking for the window is what loads the sidebar");

	[self waitForTheWorktreeLookup];

	PBSourceViewItem *group = [self worktreeGroupOnceFilledFor:windowController.sidebarViewController];
	PBSourceViewGitWorktreeItem *row = group.sortedChildren.firstObject;

	XCTAssertEqualObjects(row.title, @"parked", @"the row names the branch parked there, not the directory");
	XCTAssertEqualObjects(row.worktree.path.lastPathComponent, @"second", @"the directory is still what the model holds");
	XCTAssertTrue([row.statusDescription containsString:@"second"],
				  @"the directory moved to the tooltip, so it has to be in there: %@", row.statusDescription);

	[windowController close];
}

- (void)testABranchHeldInAnotherWorktreeIsListedOnlyUnderWorktrees
{
	PBWorktreeStubWindowController *windowController = [[PBWorktreeStubWindowController alloc] init];
	windowController.stubRepository = self.repository;
	XCTAssertNotNil(windowController.window, @"asking for the window is what loads the sidebar");

	[self waitForTheWorktreeLookup];

	PBGitSidebarController *sidebar = windowController.sidebarViewController;
	PBSourceViewItem *group = [self worktreeGroupOnceFilledFor:sidebar];
	PBSourceViewItem *branchGroup = [self groupOfSidebar:sidebar titled:@"Branches"];
	XCTAssertNotNil(branchGroup, @"the sidebar has no BRANCHES group");

	NSArray<NSString *> *worktreeTitles = [group.sortedChildren valueForKey:@"title"];
	NSArray<NSString *> *branchTitles = [branchGroup.sortedChildren valueForKey:@"title"];

	XCTAssertTrue([worktreeTitles containsObject:@"parked"], @"WORKTREES holds %@", worktreeTitles);
	XCTAssertFalse([branchTitles containsObject:@"parked"],
				   @"a branch parked in another worktree is listed twice; BRANCHES holds %@", branchTitles);
	XCTAssertTrue([branchTitles containsObject:@"branch_one"],
				  @"the branch this window has checked out still belongs in BRANCHES: %@", branchTitles);

	[windowController close];
}

- (void)testAWorktreeRowAnswersWithItsBranchSoTheRefMenuCanBeBuilt
{
	PBWorktreeStubWindowController *windowController = [[PBWorktreeStubWindowController alloc] init];
	windowController.stubRepository = self.repository;
	XCTAssertNotNil(windowController.window, @"asking for the window is what loads the sidebar");

	[self waitForTheWorktreeLookup];

	PBSourceViewItem *group = [self worktreeGroupOnceFilledFor:windowController.sidebarViewController];
	PBSourceViewGitWorktreeItem *row = group.sortedChildren.firstObject;

	XCTAssertEqualObjects(row.ref.ref, @"refs/heads/parked",
						  @"a row with no ref gets no context menu at all");
	XCTAssertEqualObjects(row.revSpecifier.ref.ref, @"refs/heads/parked",
						  @"the row stands for its branch, which is what moves the history list");

	[windowController close];
}

- (void)testEveryRowSaysWhatItIsOnHoverSoATruncatedNameStaysReadable
{
	PBWorktreeStubWindowController *windowController = [[PBWorktreeStubWindowController alloc] init];
	windowController.stubRepository = self.repository;
	XCTAssertNotNil(windowController.window, @"asking for the window is what loads the sidebar");

	[self waitForTheWorktreeLookup];

	PBGitSidebarController *sidebar = windowController.sidebarViewController;
	PBSourceViewItem *worktreeGroup = [self worktreeGroupOnceFilledFor:sidebar];
	PBSourceViewItem *branchGroup = [self groupOfSidebar:sidebar titled:@"Branches"];

	NSOutlineView *sourceView = sidebar.sourceView;
	NSTableColumn *column = sourceView.tableColumns.firstObject;

	id<NSOutlineViewDelegate> delegate = sidebar;
	NSView *branchCell = [delegate outlineView:sourceView viewForTableColumn:column item:branchGroup.sortedChildren.firstObject];
	XCTAssertEqualObjects(branchCell.toolTip, @"branch_one", @"a branch row has to name itself in full on hover");

	NSView *worktreeCell = [delegate outlineView:sourceView viewForTableColumn:column item:worktreeGroup.sortedChildren.firstObject];
	XCTAssertTrue([worktreeCell.toolTip containsString:@"parked"],
				  @"a worktree row keeps its own status on hover: %@", worktreeCell.toolTip);
	XCTAssertTrue([worktreeCell.toolTip containsString:@"on an external disk"],
				  @"the lock reason belongs on hover: %@", worktreeCell.toolTip);

	[windowController close];
}

- (void)testSelectingAWorktreeRowShowsThatBranchInTheHistoryList
{
	PBWorktreeStubWindowController *windowController = [[PBWorktreeStubWindowController alloc] init];
	windowController.stubRepository = self.repository;
	XCTAssertNotNil(windowController.window, @"asking for the window is what loads the sidebar");

	[self waitForTheWorktreeLookup];

	PBGitSidebarController *sidebar = windowController.sidebarViewController;
	PBSourceViewItem *group = [self worktreeGroupOnceFilledFor:sidebar];
	PBSourceViewItem *row = group.sortedChildren.firstObject;

	NSOutlineView *sourceView = sidebar.sourceView;
	NSInteger rowIndex = [sourceView rowForItem:row];
	XCTAssertNotEqual(rowIndex, -1, @"the worktree row is not on screen, so it cannot be clicked");

	[sourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:rowIndex] byExtendingSelection:NO];
	[(id<NSOutlineViewDelegate>)sidebar outlineViewSelectionDidChange:[NSNotification notificationWithName:NSOutlineViewSelectionDidChangeNotification object:sourceView]];

	XCTAssertEqualObjects(self.repository.currentBranch.ref.ref, @"refs/heads/parked",
						  @"the history list was left on %@", self.repository.currentBranch);

	[windowController close];
}

@end
