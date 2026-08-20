//
//  PBGitHistorySelectionTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitRevSpecifier.h"
#import "PBGitRef.h"

// Exposes the rule that decides whether a history list update is allowed to
// move the selection, and the flag the sidebar raises to ask for a move.
@interface PBGitHistoryController (SelectionTesting)
@property (nonatomic, assign) BOOL awaitingBranchSelection;
- (GTOID *)OIDToReselect;
@end

// The history list reaches for its table view once it actually moves the
// selection, which a test has no nib for, so stop at the decision.
@interface PBStubHistoryController : PBGitHistoryController
@end

@implementation PBStubHistoryController
- (BOOL)selectCommit:(GTOID *)commitOID
{
	return NO;
}
@end

static NSString *const kBranchTipSHA = @"8031ee6a0000000000000000000000000000beef";

@interface PBGitHistorySelectionTests : XCTestCase
@property (nonatomic, strong) PBGitRepository *repository;
@property (nonatomic, strong) PBGitHistoryController *historyController;
@end

@implementation PBGitHistorySelectionTests

- (void)setUp
{
	[super setUp];

	// -[PBGitRepository init] and -[PBViewController initWithRepository:...]
	// both stay in memory: no libgit2, and the nib is not loaded until the
	// view is asked for, which these tests never do.
	self.repository = [[PBGitRepository alloc] init];
	self.historyController = [[PBStubHistoryController alloc] initWithRepository:self.repository superController:nil];
}

- (void)selectBranchInSidebar:(NSString *)refName atOID:(GTOID *)OID
{
	PBGitRef *ref = [PBGitRef refFromString:refName];
	self.repository.refs = [@{OID : [@[ ref ] mutableCopy]} mutableCopy];
	self.repository.currentBranch = [[PBGitRevSpecifier alloc] initWithRef:ref];
}

// The bug: checking a branch out from the history list, a fetch, or a commit
// made in a terminal all end in a list update, and every one of them used to
// drag the selection back to the tip of whatever the sidebar had highlighted.
- (void)testAnUpdateOnItsOwnLeavesTheSelectionAlone
{
	[self selectBranchInSidebar:@"refs/heads/branch_B" atOID:[GTOID oidWithSHA:kBranchTipSHA]];
	self.historyController.awaitingBranchSelection = NO;

	XCTAssertNil([self.historyController OIDToReselect],
				 @"a list update is not a reason to move the commit the user picked");
}

// Selecting a branch in the sidebar still moves the list to that branch's tip.
- (void)testTheSidebarBranchTipIsOwedAfterABranchChange
{
	GTOID *tip = [GTOID oidWithSHA:kBranchTipSHA];
	[self selectBranchInSidebar:@"refs/heads/branch_B" atOID:tip];
	self.historyController.awaitingBranchSelection = YES;

	XCTAssertEqualObjects([self.historyController OIDToReselect], tip);
}

// The tip stays owed across updates, because the list is read in a piece at a
// time and the commit carrying the branch label may not have arrived yet.
- (void)testTheTipStaysOwedUntilItIsActuallyShown
{
	GTOID *tip = [GTOID oidWithSHA:kBranchTipSHA];
	[self selectBranchInSidebar:@"refs/heads/branch_B" atOID:tip];
	self.historyController.awaitingBranchSelection = YES;

	XCTAssertEqualObjects([self.historyController OIDToReselect], tip);
	XCTAssertEqualObjects([self.historyController OIDToReselect], tip);
}

// Clicking a branch in the sidebar is how you ask to be taken back to its tip,
// so it has to work on a branch that is already the selected one - nothing else
// moves the list back once the user has clicked away from the tip.
- (void)testClickingTheSelectedBranchAsksForItsTipAgain
{
	[self selectBranchInSidebar:@"refs/heads/branch_B" atOID:[GTOID oidWithSHA:kBranchTipSHA]];
	self.historyController.awaitingBranchSelection = NO;

	[self.historyController selectCurrentBranchTip];

	XCTAssertTrue(self.historyController.awaitingBranchSelection);
	XCTAssertEqualObjects([self.historyController OIDToReselect], [GTOID oidWithSHA:kBranchTipSHA]);
}

@end
