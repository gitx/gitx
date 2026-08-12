//
//  PBGitRevListRaceConditionTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRevList.h"

// Exposes the private state PBGitRevList's generation guard relies on, so this
// test can drive it directly without depending on FSEvents/operation-queue timing.
@interface PBGitRevList (RaceConditionTesting)
@property (nonatomic, assign) NSUInteger loadGeneration;
@property (nonatomic, assign) BOOL resetCommits;
- (void)updateCommits:(NSArray *)revisions operation:(NSOperation *)operation generation:(NSUInteger)generation;
@end

@interface PBGitRevListRaceConditionTests : XCTestCase
@end

@implementation PBGitRevListRaceConditionTests

// Reproduces the mechanism behind issue #563: a stale parse's trailing commit
// flush landing after a newer load has already started must not duplicate
// commits into -commits, even though its NSOperation was never observed as
// cancelled in time.
- (void)testStaleGenerationFlushIsDropped
{
	PBGitRevList *revList = [[PBGitRevList alloc] initWithRepository:nil rev:nil shouldGraph:NO];
	NSOperation *staleOperation = [[NSOperation alloc] init];
	NSOperation *currentOperation = [[NSOperation alloc] init];

	// Generation 1 (the first loadRevisionsWithCompletionBlock: call) flushes a batch.
	revList.resetCommits = YES;
	revList.loadGeneration = 1;
	[revList updateCommits:@[@"a", @"b"] operation:staleOperation generation:1];
	XCTAssertEqual(revList.commits.count, 2u);

	// A newer load (generation 2) starts, as an overlapping refresh would trigger,
	// and flushes a batch of its own. That flush is what consumes resetCommits and
	// clears out generation 1's commits - without it the two code paths converge on
	// the same count and the assertion below cannot tell them apart.
	revList.resetCommits = YES;
	revList.loadGeneration = 2;
	[revList updateCommits:@[@"c"] operation:currentOperation generation:2];
	XCTAssertEqual(revList.commits.count, 1u);

	// Generation 1's now-stale trailing flush arrives late, with its operation
	// still not marked cancelled (the exact race confirmed via lldb in #563).
	[revList updateCommits:@[@"a", @"b"] operation:staleOperation generation:1];

	XCTAssertEqual(revList.commits.count, 1u, @"a stale generation's flush must not land in -commits");
}

- (void)testCurrentGenerationFlushesStillAccumulate
{
	PBGitRevList *revList = [[PBGitRevList alloc] initWithRepository:nil rev:nil shouldGraph:NO];
	NSOperation *operation = [[NSOperation alloc] init];

	revList.resetCommits = YES;
	revList.loadGeneration = 1;
	[revList updateCommits:@[@"a"] operation:operation generation:1];
	[revList updateCommits:@[@"b"] operation:operation generation:1];

	XCTAssertEqual(revList.commits.count, 2u, @"batches from the current generation should still accumulate normally");
}

@end
