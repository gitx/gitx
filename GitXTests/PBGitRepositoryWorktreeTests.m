//
//  PBGitRepositoryWorktreeTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"
#import "PBGitRef.h"

// Reading the worktrees and answering for one ref are separate steps, so the
// test names both rather than launching git for them.
@interface PBGitRepository (WorktreeTesting)
+ (NSDictionary<NSString *, NSString *> *)worktreePathsFromPorcelain:(NSString *)output excludingWorktreeAtPath:(NSString *)ourPath;
@end

// What `git worktree list --porcelain` prints for a repository whose own
// checkout is on master, with feature in a second worktree, a third left on a
// detached HEAD, and a fourth locked.
static NSString *const kPorcelain =
	@"worktree /repos/gitx\n"
	@"HEAD 0000000000000000000000000000000000000001\n"
	@"branch refs/heads/master\n"
	@"\n"
	@"worktree /repos/gitx-feature\n"
	@"HEAD 0000000000000000000000000000000000000002\n"
	@"branch refs/heads/feature\n"
	@"\n"
	@"worktree /repos/gitx-detached\n"
	@"HEAD 0000000000000000000000000000000000000003\n"
	@"detached\n"
	@"\n"
	@"worktree /repos/gitx-locked\n"
	@"HEAD 0000000000000000000000000000000000000004\n"
	@"branch refs/heads/locked_work\n"
	@"locked\n";

@interface PBGitRepositoryWorktreeTests : XCTestCase
@property (nonatomic, strong) PBGitRepository *repository;
@end

@implementation PBGitRepositoryWorktreeTests

- (void)setUp
{
	[super setUp];

	// The lookup answers from what was read, so the repository needs nothing
	// of libgit2 or git here.
	self.repository = [[PBGitRepository alloc] init];
}

- (void)useWorktreePaths:(NSDictionary *)paths
{
	[self.repository setValue:paths forKey:@"worktreePathsByRefName"];
}

- (void)testEveryBranchInAWorktreeIsRead
{
	NSDictionary *paths = [PBGitRepository worktreePathsFromPorcelain:kPorcelain excludingWorktreeAtPath:nil];

	XCTAssertEqualObjects(paths[@"refs/heads/master"], @"/repos/gitx");
	XCTAssertEqualObjects(paths[@"refs/heads/feature"], @"/repos/gitx-feature");
	XCTAssertEqualObjects(paths[@"refs/heads/locked_work"], @"/repos/gitx-locked");
}

- (void)testAWorktreeOnADetachedHeadHoldsNoBranch
{
	NSDictionary *paths = [PBGitRepository worktreePathsFromPorcelain:kPorcelain excludingWorktreeAtPath:nil];

	XCTAssertEqual(paths.count, 3u, @"%@", paths);
	XCTAssertFalse([[paths allValues] containsObject:@"/repos/gitx-detached"]);
}

- (void)testABareRepositoryHoldsNoBranch
{
	NSString *porcelain = @"worktree /repos/gitx.git\nbare\n";

	XCTAssertEqualObjects([PBGitRepository worktreePathsFromPorcelain:porcelain excludingWorktreeAtPath:nil], @{});
}

- (void)testNothingIsReadFromEmptyOutput
{
	XCTAssertEqualObjects([PBGitRepository worktreePathsFromPorcelain:@"" excludingWorktreeAtPath:nil], @{});
}

// The main working tree is a worktree too, so the branch this window has
// checked out would answer for itself without this.
- (void)testTheBranchWeHaveCheckedOutOurselvesIsNotHeldElsewhere
{
	NSDictionary *paths = [PBGitRepository worktreePathsFromPorcelain:kPorcelain excludingWorktreeAtPath:@"/repos/gitx"];

	XCTAssertNil(paths[@"refs/heads/master"]);
	XCTAssertEqualObjects(paths[@"refs/heads/feature"], @"/repos/gitx-feature");
}

// `git worktree add --force` puts one branch in two worktrees. Dropping our own
// by name used to take the other holder with it.
- (void)testABranchOurWorktreeSharesWithAnotherIsStillHeldThere
{
	NSString *porcelain =
		@"worktree /repos/gitx\n"
		@"HEAD 0000000000000000000000000000000000000001\n"
		@"branch refs/heads/shared\n"
		@"\n"
		@"worktree /repos/gitx-second\n"
		@"HEAD 0000000000000000000000000000000000000001\n"
		@"branch refs/heads/shared\n";

	NSDictionary *paths = [PBGitRepository worktreePathsFromPorcelain:porcelain excludingWorktreeAtPath:@"/repos/gitx"];

	XCTAssertEqualObjects(paths[@"refs/heads/shared"], @"/repos/gitx-second");
}

// Our own entry is the one to drop wherever it appears in the listing.
- (void)testOurOwnWorktreeIsDroppedEvenWhenItIsNotListedFirst
{
	NSDictionary *paths = [PBGitRepository worktreePathsFromPorcelain:kPorcelain excludingWorktreeAtPath:@"/repos/gitx-feature"];

	XCTAssertNil(paths[@"refs/heads/feature"]);
	XCTAssertEqualObjects(paths[@"refs/heads/master"], @"/repos/gitx");
}

// git prints the resolved path, which need not match the spelling we hold.
- (void)testOurOwnWorktreeIsRecognisedThroughAnUntidyPath
{
	NSDictionary *paths = [PBGitRepository worktreePathsFromPorcelain:kPorcelain excludingWorktreeAtPath:@"/repos/./gitx"];

	XCTAssertNil(paths[@"refs/heads/master"]);
}

- (void)testTheWorktreeHoldingABranchIsFoundByItsRef
{
	[self useWorktreePaths:@{@"refs/heads/feature" : @"/repos/gitx-feature"}];

	XCTAssertEqualObjects([self.repository pathOfWorktreeHoldingRef:[PBGitRef refFromString:@"refs/heads/feature"]], @"/repos/gitx-feature");
}

- (void)testABranchInNoWorktreeIsNotFound
{
	[self useWorktreePaths:@{@"refs/heads/feature" : @"/repos/gitx-feature"}];

	XCTAssertNil([self.repository pathOfWorktreeHoldingRef:[PBGitRef refFromString:@"refs/heads/other"]]);
	XCTAssertNil([self.repository pathOfWorktreeHoldingRef:nil]);
}


- (void)testABranchHeldElsewhereIsToldFromOneThatIsNot
{
	[self useWorktreePaths:@{@"refs/heads/feature" : @"/repos/gitx-feature"}];

	XCTAssertTrue([self.repository isRefHeldByAnotherWorktree:[PBGitRef refFromString:@"refs/heads/feature"]]);
	XCTAssertFalse([self.repository isRefHeldByAnotherWorktree:[PBGitRef refFromString:@"refs/heads/other"]]);
}

// `update-ref -d` has none of the safety `git branch -d` has: it would delete
// the ref and leave the other worktree on a branch that no longer exists.
- (void)testRemovingABranchHeldElsewhereIsRefusedBeforeGitRuns
{
	[self useWorktreePaths:@{@"refs/heads/feature" : @"/repos/gitx-feature"}];

	NSError *error = nil;
	XCTAssertFalse([self.repository deleteRef:[PBGitRef refFromString:@"refs/heads/feature"] error:&error]);
	XCTAssertNotNil(error);
	XCTAssertTrue([error.localizedFailureReason containsString:@"/repos/gitx-feature"], @"%@", error.localizedFailureReason);
}

@end
