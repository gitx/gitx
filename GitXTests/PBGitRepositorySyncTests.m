//
//  PBGitRepositorySyncTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitIndex.h"
#import "PBGitRepository.h"
#import "PBGitHistoryList.h"
#import "PBGitRevSpecifier.h"

@interface PBCountingIndex : PBGitIndex
@property (nonatomic, assign) NSUInteger refreshCount;
@end

@implementation PBCountingIndex

- (void)refresh
{
	self.refreshCount++;
}

@end

@interface PBCountingHistoryList : PBGitHistoryList
@property (nonatomic, assign) NSUInteger updateCount;
@end

@implementation PBCountingHistoryList

- (void)updateHistory
{
	self.updateCount++;
}

@end

@interface PBSyncStubRepository : PBGitRepository
@property (nonatomic, strong) PBCountingIndex *countingIndex;
@property (nonatomic, strong) PBGitRevSpecifier *stubCurrentBranch;
@property (nonatomic, assign) NSUInteger reloadRefsCount;
@end

@implementation PBSyncStubRepository

- (PBGitIndex *)index
{
	return self.countingIndex;
}

- (PBGitRevSpecifier *)currentBranch
{
	return self.stubCurrentBranch;
}

- (void)reloadRefs
{
	self.reloadRefsCount++;
}

@end

@interface PBGitRepositorySyncTests : XCTestCase
@property (nonatomic, strong) PBSyncStubRepository *repository;
@property (nonatomic, strong) PBCountingHistoryList *historyList;
@end

@implementation PBGitRepositorySyncTests

- (void)setUp
{
	[super setUp];

	self.repository = [[PBSyncStubRepository alloc] init];
	self.repository.countingIndex = [[PBCountingIndex alloc] initWithRepository:self.repository];
	self.historyList = [[PBCountingHistoryList alloc] initWithRepository:self.repository];
	self.repository.revisionList = self.historyList;
}

- (void)testSyncReadsTheIndexAndTheHistory
{
	self.repository.stubCurrentBranch = [PBGitRevSpecifier allBranchesRevSpec];

	[self.repository syncWithWorkingTree];

	XCTAssertEqual(self.repository.countingIndex.refreshCount, 1u, @"the stage list is git's index, read once");
	XCTAssertEqual(self.historyList.updateCount, 1u, @"the history is the same sync, not a second event type");
}

- (void)testSyncWithoutACurrentBranchStillReadsTheIndex
{
	[self.repository syncWithWorkingTree];

	XCTAssertEqual(self.repository.countingIndex.refreshCount, 1u, @"a file save has to reach the commit view even before a branch is selected");
	XCTAssertEqual(self.repository.reloadRefsCount, 1u, @"refs still have to be read so the sidebar can catch a new branch");
	XCTAssertEqual(self.historyList.updateCount, 0u, @"there is no history to walk until a branch exists");
}

// The old suite proved an Index event from a terminal `git add` reached the
// commit view. There is no typed Index event any more: the same write is a
// disk note, and sync is what reads it.
- (void)testAnIndexWrittenOutsideGitXIsReadBySync
{
	self.repository.stubCurrentBranch = [PBGitRevSpecifier allBranchesRevSpec];

	[self.repository syncWithWorkingTree];

	XCTAssertEqual(self.repository.countingIndex.refreshCount, 1u, @"a commit or add made in a terminal has to reach the stage list");
}

@end
