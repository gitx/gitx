//
//  PBGitWorktreeManagementTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"
#import "PBGitWorktree.h"
#import "PBGitBinary.h"
#import "PBGitHistoryController.h"
#import "PBGitRef.h"

@interface PBGitRepository (WorktreeManagementTesting)
- (void)reloadWorktreePaths;
@end

@interface PBGitHistoryController (WorktreeManagementTesting)
@property (nonatomic, copy) NSString *gitVersion;
@end

@interface PBGitWorktreeManagementTests : XCTestCase
@property (nonatomic, strong) NSURL *repositoryURL;
@property (nonatomic, strong) NSURL *secondWorktreeURL;
@property (nonatomic, strong) PBGitRepository *repository;
@property (nonatomic, strong) PBGitHistoryController *menus;
@end

@implementation PBGitWorktreeManagementTests

- (void)runGit:(NSArray<NSString *> *)arguments in:(NSURL *)directory
{
	NSTask *task = [[NSTask alloc] init];
	task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/git"];
	task.currentDirectoryURL = directory;
	task.arguments = arguments;
	task.environment = @{@"GIT_AUTHOR_NAME" : @"t", @"GIT_AUTHOR_EMAIL" : @"t@t", @"GIT_COMMITTER_NAME" : @"t", @"GIT_COMMITTER_EMAIL" : @"t@t", @"PATH" : @"/usr/bin:/bin", @"GIT_CONFIG_GLOBAL" : @"/dev/null", @"GIT_CONFIG_SYSTEM" : @"/dev/null"};

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

	NSURL *root = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
	[[NSFileManager defaultManager] createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:NULL];

	self.repositoryURL = [root URLByAppendingPathComponent:@"main"];
	self.secondWorktreeURL = [root URLByAppendingPathComponent:@"second"];
	[[NSFileManager defaultManager] createDirectoryAtURL:self.repositoryURL withIntermediateDirectories:YES attributes:nil error:NULL];

	[self runGit:@[ @"init", @"-q" ] in:self.repositoryURL];
	[self runGit:@[ @"commit", @"-q", @"--allow-empty", @"-m", @"root" ] in:self.repositoryURL];
	[self runGit:@[ @"worktree", @"add", @"-q", self.secondWorktreeURL.path, @"-b", @"parked" ] in:self.repositoryURL];

	NSError *error = nil;
	self.repository = [[PBGitRepository alloc] initWithURL:self.repositoryURL error:&error];
	XCTAssertNotNil(self.repository, @"%@", error);

	self.menus = [[PBGitHistoryController alloc] initWithRepository:self.repository superController:nil];
	self.menus.gitVersion = @"2.50.1";

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second != nil;
	}];
}

- (void)tearDown
{
	NSURL *lockFile = [self.repositoryURL URLByAppendingPathComponent:@".git/worktrees/second/locked"];
	if ([lockFile checkResourceIsReachableAndReturnError:NULL])
		[self runGit:@[ @"worktree", @"unlock", self.secondWorktreeURL.path ] in:self.repositoryURL];
	[[NSFileManager defaultManager] removeItemAtURL:[self.repositoryURL URLByDeletingLastPathComponent] error:NULL];

	[super tearDown];
}

- (PBGitWorktree *)worktreeNamed:(NSString *)name
{
	for (PBGitWorktree *worktree in self.repository.worktrees)
		if ([worktree.path.lastPathComponent isEqualToString:name])
			return worktree;

	return nil;
}

- (PBGitWorktree *)second
{
	return [self worktreeNamed:@"second"];
}

- (PBGitWorktree *)main
{
	return [self worktreeNamed:@"main"];
}

- (void)waitForWorktrees:(BOOL (^)(PBGitWorktree *second))condition
{
	[self.repository reloadWorktreePaths];

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:10];
	while (!condition([self second]) && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
}

- (void)moveTheSecondFolderAway
{
	NSURL *moved = [self.secondWorktreeURL URLByAppendingPathExtension:@"moved"];
	XCTAssertTrue([[NSFileManager defaultManager] moveItemAtURL:self.secondWorktreeURL toURL:moved error:NULL]);
}

// A disabled item carries no action, so that nothing re-enables it, which
// leaves its title as the way to find it.
- (NSMenuItem *)item:(NSString *)title in:(NSArray<NSMenuItem *> *)items
{
	for (NSMenuItem *item in items)
		if ([item.title hasPrefix:title])
			return item;

	return nil;
}

- (NSArray<NSArray<NSString *> *> *)titlesOfFirstTwoGroupsIn:(NSArray<NSMenuItem *> *)items
{
	NSMutableArray<NSMutableArray<NSString *> *> *groups = [NSMutableArray arrayWithObject:[NSMutableArray array]];
	for (NSMenuItem *item in items) {
		if (item.isSeparatorItem) {
			if (groups.count == 2)
				break;
			[groups addObject:[NSMutableArray array]];
			continue;
		}
		[groups.lastObject addObject:[item.title componentsSeparatedByString:@" “"].firstObject];
	}

	return groups;
}

#pragma mark Lock and unlock

- (void)testLockingAWorktreeRecordsTheReasonGitShows
{
	NSError *error = nil;
	XCTAssertTrue([self.repository lockWorktree:[self second] reason:@"on an external disk" error:&error], @"%@", error);

	// A lookup already under way can catch the lock file before its reason is
	// written, and the refresh the lock asked for corrects that a moment later.
	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return [second.lockReason isEqualToString:@"on an external disk"];
	}];

	XCTAssertTrue([self second].isLocked, @"the sidebar has to learn of the lock without a manual refresh");
	XCTAssertEqualObjects([self second].lockReason, @"on an external disk");
}

- (void)testAWorktreeCanBeLockedWithoutAReason
{
	NSError *error = nil;
	XCTAssertTrue([self.repository lockWorktree:[self second] reason:@"" error:&error], @"%@", error);

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second.isLocked;
	}];

	XCTAssertTrue([self second].isLocked);
	XCTAssertNil([self second].lockReason, @"an empty reason is no reason, not an empty one");
}

- (void)testUnlockingTakesTheLockOff
{
	[self runGit:@[ @"worktree", @"lock", self.secondWorktreeURL.path ] in:self.repositoryURL];
	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second.isLocked;
	}];

	NSError *error = nil;
	XCTAssertTrue([self.repository unlockWorktree:[self second] error:&error], @"%@", error);

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return !second.isLocked;
	}];

	XCTAssertFalse([self second].isLocked);
}

- (void)testARefusalFromGitIsPassedOnInItsOwnWords
{
	NSError *error = nil;
	XCTAssertFalse([self.repository lockWorktree:[self main] reason:nil error:&error]);

	XCTAssertTrue([error.localizedFailureReason containsString:@"main working tree"], @"%@", error.localizedFailureReason);
}

#pragma mark Prune

- (void)testNothingIsReportedWhileEveryFolderIsThere
{
	NSError *error = nil;
	NSString *report = [self.repository worktreePruneReportWithError:&error];

	XCTAssertEqualObjects(report, @"", @"%@", error);
}

- (void)testTheReportNamesAWorktreeWhoseFolderIsGoneAndPrunesNothing
{
	[self moveTheSecondFolderAway];

	NSError *error = nil;
	NSString *report = [self.repository worktreePruneReportWithError:&error];

	XCTAssertTrue([report containsString:@"second"], @"%@ %@", report, error);
	XCTAssertTrue([report containsString:@"non-existent location"], @"git's reason belongs in the report: %@", report);

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second.isPrunable;
	}];
	XCTAssertNotNil([self second], @"asking what would be pruned must not prune it");
}

- (void)testPruningForgetsAWorktreeWhoseFolderIsGone
{
	[self moveTheSecondFolderAway];

	NSError *error = nil;
	XCTAssertTrue([self.repository pruneWorktreesWithError:&error], @"%@", error);

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second == nil;
	}];

	XCTAssertNil([self second]);
	XCTAssertNotNil([self main]);
}

#pragma mark The worktree row menu

- (void)testAWorktreeRowOffersToRevealItsFolder
{
	NSMenuItem *reveal = [self item:@"Reveal Worktree in Finder" in:[self.menus menuItemsForWorktree:[self second]]];

	XCTAssertNotNil(reveal);
	XCTAssertTrue(reveal.isEnabled);
	XCTAssertTrue(reveal.action == @selector(revealWorktreeInFinder:));
	XCTAssertEqualObjects(reveal.representedObject, [self second]);
}

- (void)testAFolderThatIsGoneCannotBeRevealedAndSaysSo
{
	[self moveTheSecondFolderAway];

	NSMenuItem *reveal = [self item:@"Reveal Worktree in Finder" in:[self.menus menuItemsForWorktree:[self second]]];

	XCTAssertFalse(reveal.isEnabled);
	XCTAssertTrue(reveal.toolTip.length > 0);
}

- (void)testAnUnlockedWorktreeOffersLockAndNotUnlock
{
	NSArray<NSMenuItem *> *items = [self.menus menuItemsForWorktree:[self second]];

	XCTAssertTrue([self item:@"Lock Worktree" in:items].isEnabled);
	XCTAssertNil([self item:@"Unlock Worktree" in:items]);
}

- (void)testALockedWorktreeOffersUnlockAndNotLock
{
	[self runGit:@[ @"worktree", @"lock", self.secondWorktreeURL.path ] in:self.repositoryURL];
	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second.isLocked;
	}];

	NSArray<NSMenuItem *> *items = [self.menus menuItemsForWorktree:[self second]];

	XCTAssertTrue([self item:@"Unlock Worktree" in:items].isEnabled);
	XCTAssertNil([self item:@"Lock Worktree" in:items]);
}

- (void)testTheMainWorktreeCannotBeLockedAndSaysWhy
{
	NSMenuItem *lock = [self item:@"Lock Worktree" in:[self.menus menuItemsForWorktree:[self main]]];

	XCTAssertNotNil(lock, @"a missing item leaves the user wondering; a disabled one can explain");
	XCTAssertFalse(lock.isEnabled);
	XCTAssertTrue([lock.toolTip containsString:@"main worktree"], @"%@", lock.toolTip);
}

- (void)testAGitTooOldToLockSaysWhichVersionItNeeds
{
	self.menus.gitVersion = @"2.9.5";

	NSMenuItem *lock = [self item:@"Lock Worktree" in:[self.menus menuItemsForWorktree:[self second]]];

	XCTAssertFalse(lock.isEnabled);
	XCTAssertTrue([lock.toolTip containsString:@PBGitWorktreeLockVersion], @"%@", lock.toolTip);
	XCTAssertTrue([lock.toolTip containsString:@"2.9.5"], @"%@", lock.toolTip);
}

- (void)testAGitThatCannotReportLockStateOffersBoth
{
	self.menus.gitVersion = @"2.30.1";

	NSArray<NSMenuItem *> *items = [self.menus menuItemsForWorktree:[self second]];

	XCTAssertTrue([self item:@"Lock Worktree" in:items].isEnabled, @"before 2.31 git does not say whether it is locked");
	XCTAssertTrue([self item:@"Unlock Worktree" in:items].isEnabled);
}

#pragma mark The branch menu, shared by the sidebar and the history list

- (void)testTheWorktreeActionsFollowOpenAndCopyInAGroupOfTheirOwn
{
	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/parked"]];

	NSArray *expected = @[ @[ @"Open Worktree of Branch", @"Copy name" ], @[ @"Reveal Worktree in Finder", @"Lock Worktree…" ] ];
	XCTAssertEqualObjects([self titlesOfFirstTwoGroupsIn:items], expected);
}

- (void)testALockedWorktreeOffersUnlockWhereLockWouldBe
{
	[self runGit:@[ @"worktree", @"lock", self.secondWorktreeURL.path ] in:self.repositoryURL];
	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second.isLocked;
	}];

	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/parked"]];

	NSArray *expected = @[ @[ @"Open Worktree of Branch", @"Copy name" ], @[ @"Reveal Worktree in Finder", @"Unlock Worktree" ] ];
	XCTAssertEqualObjects([self titlesOfFirstTwoGroupsIn:items], expected);
}

- (void)testAGitThatCannotReportLockStateOffersBothInTheWorktreeGroup
{
	self.menus.gitVersion = @"2.30.1";

	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/parked"]];

	NSArray *expected = @[ @[ @"Open Worktree of Branch", @"Copy name" ], @[ @"Reveal Worktree in Finder", @"Lock Worktree…", @"Unlock Worktree" ] ];
	XCTAssertEqualObjects([self titlesOfFirstTwoGroupsIn:items], expected);
}

- (void)testTheWorktreeItemsCarryTheWorktreeRatherThanTheBranch
{
	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/parked"]];

	XCTAssertEqualObjects([self item:@"Lock Worktree" in:items].representedObject, [self second]);
	XCTAssertEqualObjects([self item:@"Reveal Worktree in Finder" in:items].representedObject, [self second]);
}

- (void)testABranchNoOtherWorktreeHoldsOffersNoWorktreeActions
{
	[self runGit:@[ @"branch", @"loose" ] in:self.repositoryURL];

	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/loose"]];

	XCTAssertNil([self item:@"Lock Worktree" in:items]);
	XCTAssertNil([self item:@"Reveal Worktree in Finder" in:items]);
}

#pragma mark The group menu

- (void)testPruneWaitsUntilSomethingIsPrunable
{
	NSMenuItem *prune = [self item:@"Prune Worktrees" in:[self.menus menuItemsForWorktreeGroup]];

	XCTAssertNotNil(prune);
	XCTAssertFalse(prune.isEnabled, @"every folder is there, so there is nothing to prune");

	[self moveTheSecondFolderAway];
	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second.isPrunable;
	}];

	XCTAssertTrue([self item:@"Prune Worktrees" in:[self.menus menuItemsForWorktreeGroup]].isEnabled);
}

- (void)testPruneIsOfferedAsSoonAsAFolderIsGoneWithoutWaitingForGit
{
	[self moveTheSecondFolderAway];

	XCTAssertFalse([self second].isPrunable, @"nothing inside .git changed, so the snapshot has not been read again");
	XCTAssertTrue([self item:@"Prune Worktrees" in:[self.menus menuItemsForWorktreeGroup]].isEnabled,
				  @"moving a folder away touches nothing git watches, so the menu has to look for itself");
}

- (void)testAGitThatCannotReportPrunableStateAlwaysOffersPrune
{
	self.menus.gitVersion = @"2.30.1";

	XCTAssertTrue([self item:@"Prune Worktrees" in:[self.menus menuItemsForWorktreeGroup]].isEnabled,
				  @"before 2.31 git does not say what is prunable, so the dry run has to decide");
}

- (void)testAGitTooOldToPruneSaysWhichVersionItNeeds
{
	self.menus.gitVersion = @"2.4.6";

	NSMenuItem *prune = [self item:@"Prune Worktrees" in:[self.menus menuItemsForWorktreeGroup]];

	XCTAssertFalse(prune.isEnabled);
	XCTAssertTrue([prune.toolTip containsString:@PBGitWorktreePruneVersion], @"%@", prune.toolTip);
	XCTAssertTrue([prune.toolTip containsString:@"2.4.6"], @"%@", prune.toolTip);
}

@end
