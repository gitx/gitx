//
//  PBGitHistoryListCleanupTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import <ObjectiveGit/ObjectiveGit.h>
#import "PBGitHistoryList.h"
#import "PBGitRepository.h"
#import "PBGitRef.h"
#import "PBGitRevSpecifier.h"

@interface PBGitHistoryList (RefRefreshTesting)
- (BOOL)haveRefsBeenModified;
@end

@interface PBRefMapRepository : PBGitRepository
@end

@implementation PBRefMapRepository

- (void)reloadRefs
{
}

@end

@interface PBGitHistoryListCleanupTests : XCTestCase
@end

@implementation PBGitHistoryListCleanupTests

// -cleanup cancels the walk and the graph queue, and cancelled operations never
// run the completion blocks that would have called -finishedGraphing. A list
// that has been told to stop is not updating any more, so it has to say so:
// anything waiting for the flag to clear is otherwise waiting for a callback
// that is never coming. The flag is set by hand here because the invariant is
// about what -cleanup leaves behind, not about how the walk got started.
- (void)testACleanedUpListReportsThatItHasStoppedUpdating
{
	PBGitHistoryList *list = [[PBGitHistoryList alloc] initWithRepository:nil];

	list.isUpdating = YES;
	[list cleanup];

	XCTAssertFalse(list.isUpdating, @"a list that was cleaned up still claims to be updating");
}

#pragma mark A ref that left is as much a change as one that arrived

- (GTOID *)OID:(NSString *)SHA
{
	return [GTOID oidWithSHA:SHA];
}

- (void)testLosingARefOIDIsAModification
{
	PBRefMapRepository *repository = [[PBRefMapRepository alloc] init];
	PBGitHistoryList *list = [[PBGitHistoryList alloc] initWithRepository:repository];
	GTOID *kept = [self OID:@"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"];
	GTOID *dropped = [self OID:@"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"];
	PBGitRef *ref = [PBGitRef refFromString:@"refs/heads/main"];

	repository.refs = [@{kept : @[ ref ], dropped : @[ ref ]} mutableCopy];
	XCTAssertTrue([list haveRefsBeenModified], @"the first snapshot has to be recorded");

	repository.refs = [@{kept : @[ ref ]} mutableCopy];
	XCTAssertTrue([list haveRefsBeenModified], @"a reset or prune that only removes an OID used to look like nothing had happened");
}

- (void)testTheSameRefOIDSetIsNotAModification
{
	PBRefMapRepository *repository = [[PBRefMapRepository alloc] init];
	PBGitHistoryList *list = [[PBGitHistoryList alloc] initWithRepository:repository];
	GTOID *OID = [self OID:@"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"];
	PBGitRef *ref = [PBGitRef refFromString:@"refs/heads/main"];

	repository.refs = [@{OID : @[ ref ]} mutableCopy];
	XCTAssertTrue([list haveRefsBeenModified]);

	repository.refs = [@{OID : @[ ref ]} mutableCopy];
	XCTAssertFalse([list haveRefsBeenModified], @"reloading the same refs is not a reason to walk the history again");
}

- (void)testAListCreatedWithRefsAlreadyLoadedDoesNotTreatThatSetAsNew
{
	PBRefMapRepository *repository = [[PBRefMapRepository alloc] init];
	GTOID *OID = [self OID:@"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"];
	PBGitRef *ref = [PBGitRef refFromString:@"refs/heads/main"];
	repository.refs = [@{OID : @[ ref ]} mutableCopy];

	PBGitHistoryList *list = [[PBGitHistoryList alloc] initWithRepository:repository];

	XCTAssertFalse([list haveRefsBeenModified], @"opening a repository is not itself a rewrite of its refs");
}

- (void)testAnUpdateThatArrivesWhileAWalkIsRunningWaits
{
	PBRefMapRepository *repository = [[PBRefMapRepository alloc] init];
	repository.currentBranch = [PBGitRevSpecifier allBranchesRevSpec];

	PBGitHistoryList *list = [[PBGitHistoryList alloc] initWithRepository:repository];
	NSMutableArray *held = list.commits;
	list.isUpdating = YES;

	[list updateHistory];

	XCTAssertEqual(list.commits, held, @"the in-flight walk keeps the list it is building");
	XCTAssertTrue(list.isUpdating, @"a second note does not start a second walk");

	[list cleanup];
	XCTAssertFalse(list.isUpdating, @"stopping the list also drops the deferred update");
}

@end
