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
#import "PBGitWindowController.h"
#import "PBSourceViewGitWorktreeItem.h"

@interface PBGitRepository (WorktreeManagementTesting)
- (void)reloadWorktreePaths;
- (NSString *)readWorktreePorcelain;
@end

@interface PBGitWindowController (WorktreeManagementTesting)
+ (NSString *)refusalFromGitMessage:(NSString *)message;
- (void)answerRefusalToRemoveWorktree:(PBGitWorktree *)worktree error:(NSError *)error;
- (void)offerToRemoveWorktree:(PBGitWorktree *)worktree anywayAfter:(NSError *)refusal;
- (NSAlert *)alertForMissingFolderOfWorktree:(PBGitWorktree *)worktree gitVersion:(NSString *)version;
@end

@interface PBRemovalRefusedWindowController : PBGitWindowController
@property (nonatomic, strong) NSError *offeredRemoveAnywayAfter;
@property (nonatomic, strong) NSError *errorShown;
@end

@implementation PBRemovalRefusedWindowController

- (void)offerToRemoveWorktree:(PBGitWorktree *)worktree anywayAfter:(NSError *)refusal
{
	self.offeredRemoveAnywayAfter = refusal;
}

- (void)showErrorSheet:(NSError *)error
{
	self.errorShown = error;
}

@end

@interface PBGitHistoryController (WorktreeManagementTesting)
@property (nonatomic, copy) NSString *gitVersion;
@end

@interface PBMissingFolderWindowController : PBGitWindowController
@property (nonatomic, strong) PBGitRepository *stubRepository;
@property (nonatomic, strong) PBGitWorktree *missingFolderExplainedFor;
@end

@implementation PBMissingFolderWindowController

- (PBGitRepository *)repository
{
	return self.stubRepository;
}

- (void)showMissingFolderOfWorktree:(PBGitWorktree *)worktree
{
	self.missingFolderExplainedFor = worktree;
}

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

- (NSString *)siblingPath:(NSString *)name
{
	return [[self.repositoryURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:name].path;
}

- (NSString *)movedSecondPath
{
	return [self.secondWorktreeURL URLByAppendingPathExtension:@"moved"].path;
}

- (void)moveTheSecondFolderAway
{
	XCTAssertTrue([[NSFileManager defaultManager] moveItemAtPath:self.secondWorktreeURL.path toPath:[self movedSecondPath] error:NULL]);
}

- (NSArray<NSString *> *)worktreePathsGitLists
{
	NSMutableArray<NSString *> *paths = [NSMutableArray array];
	for (PBGitWorktree *worktree in [PBGitWorktree worktreesFromPorcelain:[self.repository readWorktreePorcelain] currentWorktreeAtPath:nil])
		[paths addObject:worktree.path.lastPathComponent];

	return paths;
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

- (void)testAMovedWorktreeIsFoundAgainWhereItWent
{
	[self moveTheSecondFolderAway];

	NSError *error = nil;
	XCTAssertTrue([self.repository repairWorktree:[self second] movedTo:[self movedSecondPath] error:&error], @"%@", error);

	XCTAssertEqualObjects([self worktreePathsGitLists], (@[ @"main", @"second.moved" ]));

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return [self worktreeNamed:@"second.moved"] != nil;
	}];
	XCTAssertFalse([self worktreeNamed:@"second.moved"].isPrunable);
}

- (void)testAMovedLockedWorktreeIsFoundAgainAndStaysLocked
{
	[self runGit:@[ @"worktree", @"lock", @"--reason", @"on the usb disk", self.secondWorktreeURL.path ] in:self.repositoryURL];
	[self moveTheSecondFolderAway];

	NSError *error = nil;
	XCTAssertTrue([self.repository repairWorktree:[self second] movedTo:[self movedSecondPath] error:&error], @"%@", error);

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return [self worktreeNamed:@"second.moved"] != nil;
	}];
	XCTAssertEqualObjects([self worktreeNamed:@"second.moved"].lockReason, @"on the usb disk");
	[self runGit:@[ @"worktree", @"unlock", [self movedSecondPath] ] in:self.repositoryURL];
}

- (void)testTheFolderOfAnotherWorktreeIsRefused
{
	[self moveTheSecondFolderAway];

	NSError *error = nil;
	XCTAssertFalse([self.repository repairWorktree:[self second] movedTo:self.repositoryURL.path error:&error]);

	XCTAssertTrue([error.localizedFailureReason containsString:@"already"], @"%@", error.localizedFailureReason);
	XCTAssertEqualObjects([self worktreePathsGitLists], (@[ @"main", @"second" ]));
}

- (void)testAFolderThatIsNoWorktreeIsRefusedInGitsWords
{
	[self moveTheSecondFolderAway];
	NSString *plain = [self siblingPath:@"plain"];
	[[NSFileManager defaultManager] createDirectoryAtPath:plain withIntermediateDirectories:NO attributes:nil error:NULL];

	NSError *error = nil;
	XCTAssertFalse([self.repository repairWorktree:[self second] movedTo:plain error:&error]);

	XCTAssertTrue(error.localizedFailureReason.length > 0);
	XCTAssertEqualObjects([self worktreePathsGitLists], (@[ @"main", @"second" ]));
}

- (void)testTheMovedFolderOfAnotherWorktreeIsNotTakenForThisOne
{
	NSString *third = [self siblingPath:@"third"];
	[self runGit:@[ @"worktree", @"add", @"-q", third, @"-b", @"other" ] in:self.repositoryURL];
	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return [self worktreeNamed:@"third"] != nil;
	}];
	[self moveTheSecondFolderAway];
	NSString *movedThird = [third stringByAppendingPathExtension:@"moved"];
	XCTAssertTrue([[NSFileManager defaultManager] moveItemAtPath:third toPath:movedThird error:NULL]);

	NSError *error = nil;
	XCTAssertFalse([self.repository repairWorktree:[self second] movedTo:movedThird error:&error]);

	XCTAssertTrue([error.localizedFailureReason containsString:self.secondWorktreeURL.lastPathComponent], @"%@", error.localizedFailureReason);
	XCTAssertTrue([[self worktreePathsGitLists] containsObject:@"second"], @"the worktree asked about is still where it was");
}

- (void)testAWorktreeRowOffersToRevealItsFolder
{
	NSMenuItem *reveal = [self item:@"Reveal Worktree in Finder" in:[self.menus menuItemsForWorktree:[self second]]];

	XCTAssertNotNil(reveal);
	XCTAssertTrue(reveal.isEnabled);
	XCTAssertTrue(reveal.action == @selector(revealWorktreeInFinder:));
	XCTAssertEqualObjects(reveal.representedObject, [self second]);
}

- (void)testAFolderThatIsGoneIsOfferedToBeLocatedWhereRevealWas
{
	[self moveTheSecondFolderAway];

	NSArray<NSMenuItem *> *items = [self.menus menuItemsForWorktree:[self second]];
	NSMenuItem *locate = [self item:@"Locate Worktree Folder" in:items];

	XCTAssertEqualObjects(items.firstObject, locate);
	XCTAssertNil([self item:@"Reveal Worktree in Finder" in:items], @"there is nothing to reveal");
	XCTAssertTrue(locate.isEnabled);
	XCTAssertTrue(locate.action == @selector(locateWorktreeFolder:));
	XCTAssertEqualObjects(locate.representedObject, [self second]);
}

- (void)testAWorktreeWithItsFolderIsNotOfferedToBeLocated
{
	XCTAssertNil([self item:@"Locate Worktree Folder" in:[self.menus menuItemsForWorktree:[self second]]]);
}

- (void)testAGitTooOldToRepairSaysWhichVersionItNeeds
{
	self.menus.gitVersion = @"2.28.1";
	[self moveTheSecondFolderAway];

	NSMenuItem *locate = [self item:@"Locate Worktree Folder" in:[self.menus menuItemsForWorktree:[self second]]];

	XCTAssertFalse(locate.isEnabled);
	XCTAssertTrue([locate.toolTip containsString:@PBGitWorktreeRepairVersion], @"%@", locate.toolTip);
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

#pragma mark A worktree whose folder is gone

- (void)testAWorktreeWhoseFolderIsGoneIsUnavailableBeforeGitIsAskedAgain
{
	[self moveTheSecondFolderAway];

	PBSourceViewGitWorktreeItem *row = [PBSourceViewGitWorktreeItem itemWithWorktree:[self second]];

	XCTAssertFalse([self second].isPrunable, @"nothing has read the worktrees again yet");
	XCTAssertTrue(row.isUnavailable);
	XCTAssertTrue([row.statusDescription containsString:@"folder"], @"%@", row.statusDescription);
}

- (void)testAWorktreeWithItsFolderIsAvailable
{
	XCTAssertFalse([PBSourceViewGitWorktreeItem itemWithWorktree:[self second]].isUnavailable);
}

// The menu and a double click on the branch label both land here.
- (void)testOpeningAWorktreeWhoseFolderIsGoneExplainsInsteadOfOpening
{
	[self moveTheSecondFolderAway];

	PBMissingFolderWindowController *windowController = [[PBMissingFolderWindowController alloc] init];
	windowController.stubRepository = self.repository;

	[windowController openWorktreeHoldingRef:[PBGitRef refFromString:@"refs/heads/parked"]];

	XCTAssertEqualObjects(windowController.missingFolderExplainedFor, [self second]);
}

- (void)testTheMissingFolderSheetOffersToLocateTheFolder
{
	[self moveTheSecondFolderAway];

	NSAlert *alert = [[[PBGitWindowController alloc] init] alertForMissingFolderOfWorktree:[self second] gitVersion:@"2.50.1"];

	XCTAssertEqualObjects([alert.buttons valueForKey:@"title"], (@[ @"OK", @"Locate Folder…" ]));
}

- (void)testTheMissingFolderSheetOffersNoLocateToAGitTooOldToRepair
{
	[self moveTheSecondFolderAway];

	NSAlert *alert = [[[PBGitWindowController alloc] init] alertForMissingFolderOfWorktree:[self second] gitVersion:@"2.28.1"];

	XCTAssertEqualObjects([alert.buttons valueForKey:@"title"], (@[ @"OK" ]));
}

#pragma mark The branch menu, shared by the sidebar and the history list

- (void)testTheWorktreeActionsFollowOpenAndCopyInAGroupOfTheirOwn
{
	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/parked"]];

	NSArray *expected = @[ @[ @"Open Worktree of Branch", @"Copy name" ], @[ @"Reveal Worktree in Finder", @"Lock Worktree…" ] ];
	XCTAssertEqualObjects([self titlesOfFirstTwoGroupsIn:items], expected);
}

- (void)testABranchWhoseWorktreeFolderIsGoneOffersLocateWhereRevealWouldBe
{
	[self moveTheSecondFolderAway];

	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/parked"]];

	NSArray *expected = @[ @[ @"Open Worktree of Branch", @"Copy name" ], @[ @"Locate Worktree Folder…", @"Lock Worktree…" ] ];
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

#pragma mark Add and remove

- (void)testAnExistingBranchCanBeCheckedOutInANewWorktree
{
	[self runGit:@[ @"branch", @"loose" ] in:self.repositoryURL];

	NSError *error = nil;
	XCTAssertTrue([self.repository addWorktreeAtPath:[self siblingPath:@"loose-here"] branch:[PBGitRef refFromString:@"refs/heads/loose"] error:&error], @"%@", error);

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return [self worktreeNamed:@"loose-here"] != nil;
	}];
	XCTAssertEqualObjects([self worktreeNamed:@"loose-here"].branchRefName, @"refs/heads/loose");
}

- (void)testANewWorktreeCanStartANewBranch
{
	NSError *error = nil;
	XCTAssertTrue([self.repository addWorktreeAtPath:[self siblingPath:@"fresh-here"] newBranchNamed:@"fresh" error:&error], @"%@", error);

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return [self worktreeNamed:@"fresh-here"] != nil;
	}];
	XCTAssertEqualObjects([self worktreeNamed:@"fresh-here"].branchRefName, @"refs/heads/fresh");
}

- (void)testANewBranchThatAlreadyExistsIsRefusedInGitsWords
{
	NSError *error = nil;
	XCTAssertFalse([self.repository addWorktreeAtPath:[self siblingPath:@"clash"] newBranchNamed:@"parked" error:&error]);

	XCTAssertTrue([error.localizedFailureReason containsString:@"already exists"], @"%@", error.localizedFailureReason);
}

- (void)testACleanWorktreeIsRemovedWithItsFolder
{
	NSError *error = nil;
	XCTAssertTrue([self.repository removeWorktree:[self second] force:NO error:&error], @"%@", error);

	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second == nil;
	}];
	XCTAssertNil([self second]);
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.secondWorktreeURL.path]);
	[self runGit:@[ @"rev-parse", @"--verify", @"-q", @"refs/heads/parked" ] in:self.repositoryURL];
}

- (void)testWorkThatWouldBeLostIsRefusedUntilForced
{
	[@"not committed" writeToURL:[self.secondWorktreeURL URLByAppendingPathComponent:@"notes.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];

	NSError *error = nil;
	XCTAssertFalse([self.repository removeWorktree:[self second] force:NO error:&error]);
	XCTAssertTrue([error.localizedFailureReason containsString:@"untracked"], @"git's own reason is what the sheet shows: %@", error.localizedFailureReason);
	XCTAssertTrue([[NSFileManager defaultManager] fileExistsAtPath:self.secondWorktreeURL.path]);

	XCTAssertTrue([self.repository removeWorktree:[self second] force:YES error:&error], @"%@", error);
	XCTAssertFalse([[NSFileManager defaultManager] fileExistsAtPath:self.secondWorktreeURL.path]);
}

// The sheet offers Remove Anyway itself, so git's advice for the command line
// and its "fatal:" have no place in it; the reason stays in git's words.
- (void)testTheRefusalShowsGitsReasonWithoutItsCommandLineAdvice
{
	NSString *git = @"fatal: '../dirty' contains modified or untracked files, use --force to delete it";

	XCTAssertEqualObjects([PBGitWindowController refusalFromGitMessage:git], @"'../dirty' contains modified or untracked files");
}

- (void)testARefusalWithNothingToStripIsLeftAsItIs
{
	XCTAssertEqualObjects([PBGitWindowController refusalFromGitMessage:@"Permission denied"], @"Permission denied");
}

- (PBRemovalRefusedWindowController *)answerToRemovingTheSecondWorktree
{
	NSError *error = nil;
	XCTAssertFalse([self.repository removeWorktree:[self second] force:NO error:&error], @"git was expected to refuse");

	PBRemovalRefusedWindowController *windowController = [[PBRemovalRefusedWindowController alloc] init];
	[windowController answerRefusalToRemoveWorktree:[self second] error:error];

	return windowController;
}

- (void)testWorkThatWouldBeLostIsOfferedRemoveAnyway
{
	[@"not committed" writeToURL:[self.secondWorktreeURL URLByAppendingPathComponent:@"notes.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];

	PBRemovalRefusedWindowController *windowController = [self answerToRemovingTheSecondWorktree];

	XCTAssertNotNil(windowController.offeredRemoveAnywayAfter);
	XCTAssertNil(windowController.errorShown);
}

- (void)testAWorktreeWithASubmoduleIsOfferedRemoveAnyway
{
	NSURL *library = [[self.repositoryURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:@"library"];
	[[NSFileManager defaultManager] createDirectoryAtURL:library withIntermediateDirectories:YES attributes:nil error:NULL];
	[self runGit:@[ @"init", @"-q" ] in:library];
	[self runGit:@[ @"commit", @"-q", @"--allow-empty", @"-m", @"library" ] in:library];
	[self runGit:@[ @"-c", @"protocol.file.allow=always", @"submodule", @"add", @"-q", library.path, @"library" ] in:self.secondWorktreeURL];
	[self runGit:@[ @"commit", @"-q", @"-m", @"library" ] in:self.secondWorktreeURL];

	PBRemovalRefusedWindowController *windowController = [self answerToRemovingTheSecondWorktree];

	XCTAssertNotNil(windowController.offeredRemoveAnywayAfter, @"--force removes a worktree with submodules, though git does not say so");
	XCTAssertNil(windowController.errorShown);
}

- (void)testAWorktreeLockedSinceTheMenuWasBuiltIsNotOfferedRemoveAnyway
{
	[self runGit:@[ @"worktree", @"lock", self.secondWorktreeURL.path ] in:self.repositoryURL];

	PBRemovalRefusedWindowController *windowController = [self answerToRemovingTheSecondWorktree];

	XCTAssertNil(windowController.offeredRemoveAnywayAfter, @"--force does not remove a locked worktree, so Remove Anyway would only fail again");
	XCTAssertNotNil(windowController.errorShown);
}

#pragma mark Add and remove in the branch menu

- (void)testABranchNoWorktreeHoldsCanBeCheckedOutInANewWorktree
{
	[self runGit:@[ @"branch", @"loose" ] in:self.repositoryURL];

	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/loose"]];

	NSArray *expected = @[ @[ @"Checkout", @"Copy name" ], @[ @"Checkout" ] ];
	XCTAssertEqualObjects([self titlesOfFirstTwoGroupsIn:items], expected, @"%@", [items valueForKey:@"title"]);
	NSMenuItem *add = [self item:@"Checkout “loose” in New Worktree" in:items];
	XCTAssertTrue(add.isEnabled);
	XCTAssertTrue(add.action == @selector(checkOutInNewWorktree:));
}

- (void)testTheBranchCheckedOutHereCannotBeCheckedOutAgainAndSaysWhy
{
	NSString *here = [self main].branchRefName;
	NSString *name = [here substringFromIndex:[@"refs/heads/" length]];

	NSMenuItem *add = [self item:[NSString stringWithFormat:@"Checkout “%@” in New Worktree", name] in:[self.menus menuItemsForRef:[PBGitRef refFromString:here]]];

	XCTAssertNotNil(add);
	XCTAssertFalse(add.isEnabled);
	XCTAssertTrue(add.toolTip.length > 0);
}

- (void)testARemoteBranchIsNotOfferedANewWorktree
{
	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/remotes/origin/parked"]];

	XCTAssertNil([self item:@"Checkout “origin/parked” in New Worktree" in:items]);
}

- (void)testRemoveWorktreeTakesThePlaceOfRemovingTheBranch
{
	NSArray<NSMenuItem *> *items = [self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/parked"]];

	NSMenuItem *remove = [self item:@"Remove Worktree" in:items];
	XCTAssertTrue(remove.isEnabled);
	XCTAssertTrue(remove.action == @selector(removeWorktree:));
	XCTAssertEqualObjects(remove.representedObject, [self second]);
	XCTAssertEqualObjects(items.lastObject, remove, @"it sits where removing the branch did: %@", [items valueForKey:@"title"]);
	XCTAssertNil([self item:@"Remove “parked”" in:items], @"the branch cannot be removed while a worktree holds it");
}

- (void)testALockedWorktreeCannotBeRemovedAndSaysWhy
{
	[self runGit:@[ @"worktree", @"lock", @"--reason", @"on a USB disk", self.secondWorktreeURL.path ] in:self.repositoryURL];
	[self waitForWorktrees:^BOOL(PBGitWorktree *second) {
		return second.lockReason != nil;
	}];

	NSMenuItem *remove = [self item:@"Remove Worktree" in:[self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/parked"]]];

	XCTAssertFalse(remove.isEnabled, @"git refuses even with --force");
	XCTAssertTrue([remove.toolTip containsString:@"on a USB disk"], @"%@", remove.toolTip);
}

- (void)testAGitTooOldToRemoveSaysWhichVersionItNeeds
{
	self.menus.gitVersion = @"2.16.6";

	NSMenuItem *remove = [self item:@"Remove Worktree" in:[self.menus menuItemsForRef:[PBGitRef refFromString:@"refs/heads/parked"]]];

	XCTAssertFalse(remove.isEnabled);
	XCTAssertTrue([remove.toolTip containsString:@PBGitWorktreeRemoveVersion], @"%@", remove.toolTip);
}

- (void)testTheMainWorktreeCannotBeRemovedAndSaysWhy
{
	NSMenuItem *remove = [self item:@"Remove Worktree" in:[self.menus menuItemsForWorktree:[self main]]];

	XCTAssertFalse(remove.isEnabled);
	XCTAssertTrue([remove.toolTip containsString:@"main worktree"], @"%@", remove.toolTip);
}

- (void)testARowWithNoBranchOffersRemoveBelowTheWorktreeGroup
{
	NSArray<NSMenuItem *> *items = [self.menus menuItemsForWorktree:[self second]];

	NSArray *titles = [items valueForKey:@"title"];
	XCTAssertEqualObjects([self titlesOfFirstTwoGroupsIn:items], (@[ @[ @"Reveal Worktree in Finder", @"Lock Worktree…" ], @[ @"Remove Worktree…" ] ]), @"%@", titles);
}

#pragma mark The group menu

- (void)testTheGroupOffersToAddAWorktreeAboveTheOfferToPrune
{
	NSArray<NSMenuItem *> *items = [self.menus menuItemsForWorktreeGroup];

	XCTAssertEqualObjects([items valueForKey:@"title"], (@[ @"Add Worktree…", @"Prune Worktrees…" ]));
	XCTAssertTrue(items.firstObject.isEnabled);
	XCTAssertTrue(items.firstObject.action == @selector(addWorktree:));
}

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
