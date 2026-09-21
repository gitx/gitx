//
//  PBGitRepositoryWorktreeTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"
#import "PBGitRef.h"
#import "PBGitWorktree.h"

// Reading the worktrees and answering for one ref are separate steps, so the
// test names both rather than launching git for them.
@interface PBGitRepository (WorktreeTesting)
+ (NSDictionary<NSString *, NSString *> *)pathsByRefNameFromWorktrees:(NSArray<PBGitWorktree *> *)worktrees;
- (void)takeWorktrees:(NSArray<PBGitWorktree *> *)worktrees;
- (void)reloadWorktreePaths;
- (NSString *)readWorktreePorcelain;
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

// Counts what the history and sidebar controllers would act on: both observe
// "refs", and answer by rearranging the history or reloading the sidebar.
@interface PBRefsChangeCounter : NSObject
@property (nonatomic, assign) NSUInteger count;
@end

@implementation PBRefsChangeCounter

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	self.count++;
}

@end

// Stands in for the git process: counts how many times the lookup actually
// runs, and holds the first one open so a burst of reloads lands while it is
// still in flight.
@interface PBCountingWorktreeRepository : PBGitRepository
@property (nonatomic, assign) NSUInteger reads;
@property (nonatomic, strong) dispatch_semaphore_t held;
@end

@implementation PBCountingWorktreeRepository

- (NSString *)readWorktreePorcelain
{
	@synchronized(self) {
		self.reads++;
	}

	if (self.held)
		dispatch_semaphore_wait(self.held, DISPATCH_TIME_FOREVER);

	return @"";
}

- (NSUInteger)readsSoFar
{
	@synchronized(self) {
		return _reads;
	}
}

@end

@interface PBGitRepositoryWorktreeTests : XCTestCase
@property (nonatomic, strong) PBGitRepository *repository;
@end

@implementation PBGitRepositoryWorktreeTests

// What the lookup does between running git and storing the result: read the
// porcelain into worktrees, then derive the dictionary the drawing path asks.
- (NSDictionary<NSString *, NSString *> *)pathsFromPorcelain:(NSString *)porcelain excluding:(NSString *)ourPath
{
	return [PBGitRepository pathsByRefNameFromWorktrees:[PBGitWorktree worktreesFromPorcelain:porcelain currentWorktreeAtPath:ourPath]];
}

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
	NSDictionary *paths = [self pathsFromPorcelain:kPorcelain excluding:nil];

	XCTAssertEqualObjects(paths[@"refs/heads/master"], @"/repos/gitx");
	XCTAssertEqualObjects(paths[@"refs/heads/feature"], @"/repos/gitx-feature");
	XCTAssertEqualObjects(paths[@"refs/heads/locked_work"], @"/repos/gitx-locked");
}

- (void)testAWorktreeOnADetachedHeadHoldsNoBranch
{
	NSDictionary *paths = [self pathsFromPorcelain:kPorcelain excluding:nil];

	XCTAssertEqual(paths.count, 3u, @"%@", paths);
	XCTAssertFalse([[paths allValues] containsObject:@"/repos/gitx-detached"]);
}

- (void)testABareRepositoryHoldsNoBranch
{
	NSString *porcelain = @"worktree /repos/gitx.git\nbare\n";

	XCTAssertEqualObjects([self pathsFromPorcelain:porcelain excluding:nil], @{});
}

- (void)testNothingIsReadFromEmptyOutput
{
	XCTAssertEqualObjects([self pathsFromPorcelain:@"" excluding:nil], @{});
}

// The main working tree is a worktree too, so the branch this window has
// checked out would answer for itself without this.
- (void)testTheBranchWeHaveCheckedOutOurselvesIsNotHeldElsewhere
{
	NSDictionary *paths = [self pathsFromPorcelain:kPorcelain excluding:@"/repos/gitx"];

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

	NSDictionary *paths = [self pathsFromPorcelain:porcelain excluding:@"/repos/gitx"];

	XCTAssertEqualObjects(paths[@"refs/heads/shared"], @"/repos/gitx-second");
}

// Our own entry is the one to drop wherever it appears in the listing.
- (void)testOurOwnWorktreeIsDroppedEvenWhenItIsNotListedFirst
{
	NSDictionary *paths = [self pathsFromPorcelain:kPorcelain excluding:@"/repos/gitx-feature"];

	XCTAssertNil(paths[@"refs/heads/feature"]);
	XCTAssertEqualObjects(paths[@"refs/heads/master"], @"/repos/gitx");
}

// git prints the resolved path, which need not match the spelling we hold.
- (void)testOurOwnWorktreeIsRecognisedThroughAnUntidyPath
{
	NSDictionary *paths = [self pathsFromPorcelain:kPorcelain excluding:@"/repos/./gitx"];

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


#pragma mark The snapshot is read while drawing and refreshed away from it

// -drawLabelAtIndex: and the sidebar's cell read this while drawing, and
// -refNamesHeldByOtherWorktrees feeds an array literal, where a nil would
// raise rather than draw nothing.
- (void)testARepositoryThatHasReadNoWorktreesYetStillAnswers
{
	PBGitRepository *repository = [[PBGitRepository alloc] init];

	XCTAssertNotNil([repository valueForKey:@"worktreePathsByRefName"]);
	XCTAssertNotNil([repository refNamesHeldByOtherWorktrees]);
	XCTAssertFalse([repository isRefHeldByAnotherWorktree:[PBGitRef refFromString:@"refs/heads/feature"]]);
}

- (NSUInteger)refsChangesTaking:(NSString *)porcelain after:(NSString *)previous
{
	[self.repository takeWorktrees:[PBGitWorktree worktreesFromPorcelain:previous currentWorktreeAtPath:nil]];

	PBRefsChangeCounter *counter = [[PBRefsChangeCounter alloc] init];
	[self.repository addObserver:counter forKeyPath:@"refs" options:0 context:NULL];
	[self.repository takeWorktrees:[PBGitWorktree worktreesFromPorcelain:porcelain currentWorktreeAtPath:nil]];
	[self.repository removeObserver:counter forKeyPath:@"refs"];

	return counter.count;
}

// The refs observers rearrange the history and reload the sidebar, so a reload
// that found the same worktrees as last time has to stay quiet: otherwise
// moving the lookup off the drawing path would cost two reloads per refresh
// in place of the 9ms it saves.
- (void)testFindingTheSameWorktreesAgainAnnouncesNothing
{
	NSString *porcelain = @"worktree /repos/gitx-feature\nHEAD 0000000000000000000000000000000000000002\nbranch refs/heads/feature\n";

	XCTAssertEqual([self refsChangesTaking:[porcelain copy] after:porcelain], 0u,
				   @"an unchanged snapshot must not trigger a reload");
}

- (void)testFindingDifferentWorktreesAnnouncesTheChange
{
	XCTAssertEqual([self refsChangesTaking:@"worktree /repos/gitx-other\nHEAD 0000000000000000000000000000000000000003\nbranch refs/heads/other\n"
									 after:@"worktree /repos/gitx-feature\nHEAD 0000000000000000000000000000000000000002\nbranch refs/heads/feature\n"],
				   1u, @"a snapshot that changed has to reach the labels");
}


// -reloadRefs runs on a polling path (-haveRefsBeenModified), so a burst of
// reloads must not each start their own git process. One runs, and at most one
// more is queued behind it however many times the poll fires.
- (void)testABurstOfReloadsRunsTheLookupOnce
{
	PBCountingWorktreeRepository *repository = [[PBCountingWorktreeRepository alloc] init];
	repository.held = dispatch_semaphore_create(0);

	for (NSUInteger reload = 0; reload < 5; reload++)
		[repository reloadWorktreePaths];

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:2];
	while ([repository readsSoFar] == 0 && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	XCTAssertEqual([repository readsSoFar], 1u, @"five reloads must not start five git processes");

	dispatch_semaphore_signal(repository.held);

	limit = [NSDate dateWithTimeIntervalSinceNow:2];
	while ([repository readsSoFar] < 2 && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	XCTAssertEqual([repository readsSoFar], 2u, @"the reloads that arrived mid-flight collapse into one more run");

	dispatch_semaphore_signal(repository.held);
}

@end
