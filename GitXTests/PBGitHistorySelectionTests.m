//
//  PBGitHistorySelectionTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitRevSpecifier.h"
#import "PBGitRef.h"
#import "PBGitCommit.h"

// Exposes the rule that decides whether a history list update is allowed to
// move the selection, and the flag the sidebar raises to ask for a move.
@interface PBGitHistoryController (SelectionTesting)
@property (nonatomic, assign) BOOL awaitingBranchSelection;
@property (nonatomic, strong) GTOID *lastSelectedOID;
- (GTOID *)OIDToReselect;
- (void)restoreSelectionAfterUpdate;
- (void)scrollToSelection;
- (NSArray<PBGitCommit *> *)commitsForSender:(id)sender;
@end

// The restore only reads OIDs off the commits, so it needs nothing of the real
// PBGitCommit, which cannot be built without a commit in a repository.
@interface PBStubCommit : NSObject
@property (nonatomic, strong) GTOID *OID;
@end

@implementation PBStubCommit
+ (instancetype)commitWithSHA:(NSString *)SHA
{
	PBStubCommit *commit = [PBStubCommit new];
	commit.OID = [GTOID oidWithSHA:SHA];

	return commit;
}
@end

// The history list reaches for its table view once it actually moves the
// selection, which a test has no nib for, so stop at the decision and count
// the scrolls it asks for.
@interface PBStubHistoryController : PBGitHistoryController
@property (nonatomic, assign) NSUInteger scrollCount;
@end

@implementation PBStubHistoryController
- (BOOL)selectCommit:(GTOID *)commitOID
{
	return NO;
}

- (void)scrollToSelection
{
	self.scrollCount++;
}
@end

static NSString *const kBranchTipSHA = @"8031ee6a0000000000000000000000000000beef";

@interface PBGitHistorySelectionTests : XCTestCase
@property (nonatomic, strong) PBGitRepository *repository;
@property (nonatomic, strong) PBStubHistoryController *historyController;
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

// Checking a branch out rewrites the list, and the array controller drops a
// selection whose objects have been replaced. The commit is still there under
// the same OID, so it has to come back rather than leaving the history list
// with nothing selected and no focus.
- (void)testASelectionDroppedByARebuildComesBack
{
	NSString *pickedSHA = @"c12df1e80000000000000000000000000000cafe";
	NSArrayController *commits = [[NSArrayController alloc] init];
	commits.avoidsEmptySelection = NO;
	commits.content = @[ [PBStubCommit commitWithSHA:kBranchTipSHA], [PBStubCommit commitWithSHA:pickedSHA] ];
	[commits setSelectedObjects:@[]];
	[self.historyController setValue:commits forKey:@"commitController"];

	self.historyController.lastSelectedOID = [GTOID oidWithSHA:pickedSHA];
	self.historyController.awaitingBranchSelection = NO;

	[self.historyController restoreSelectionAfterUpdate];

	XCTAssertEqualObjects([commits.selectedObjects.firstObject OID], [GTOID oidWithSHA:pickedSHA]);
}

- (void)testARestoredSelectionIsBroughtBackIntoView
{
	NSString *pickedSHA = @"c12df1e80000000000000000000000000000cafe";
	NSArrayController *commits = [[NSArrayController alloc] init];
	commits.avoidsEmptySelection = NO;
	commits.content = @[ [PBStubCommit commitWithSHA:kBranchTipSHA], [PBStubCommit commitWithSHA:pickedSHA] ];
	[commits setSelectedObjects:@[]];
	[self.historyController setValue:commits forKey:@"commitController"];

	self.historyController.lastSelectedOID = [GTOID oidWithSHA:pickedSHA];

	[self.historyController restoreSelectionAfterUpdate];

	XCTAssertEqual(self.historyController.scrollCount, 1u, @"a selection nobody can see is not a selection");
}

- (void)testASelectionThatWasNeverDroppedIsLeftWhereItIs
{
	NSArrayController *commits = [[NSArrayController alloc] init];
	commits.content = @[ [PBStubCommit commitWithSHA:kBranchTipSHA] ];
	[commits setSelectedObjects:commits.content];
	[self.historyController setValue:commits forKey:@"commitController"];

	self.historyController.lastSelectedOID = [GTOID oidWithSHA:kBranchTipSHA];

	[self.historyController restoreSelectionAfterUpdate];

	XCTAssertEqual(self.historyController.scrollCount, 0u, @"an update on its own is no reason to move the list under the user");
}

// A branch change outranks it: there the list is meant to move.
- (void)testAnOutstandingBranchChangeIsNotOverriddenByTheRestore
{
	NSArrayController *commits = [[NSArrayController alloc] init];
	commits.avoidsEmptySelection = NO;
	commits.content = @[ [PBStubCommit commitWithSHA:kBranchTipSHA] ];
	[commits setSelectedObjects:@[]];
	[self.historyController setValue:commits forKey:@"commitController"];

	[self selectBranchInSidebar:@"refs/heads/branch_B" atOID:[GTOID oidWithSHA:kBranchTipSHA]];
	self.historyController.awaitingBranchSelection = YES;

	XCTAssertEqualObjects([self.historyController OIDToReselect], [GTOID oidWithSHA:kBranchTipSHA]);
}

// The bug (#406): right-clicking a commit other than the selected one showed the
// menu for the clicked commit, but Copy SHA and friends copied the selection.
- (NSArrayController *)commitsWithSelection:(NSArray *)selection
{
	NSArrayController *commits = [[NSArrayController alloc] init];
	commits.avoidsEmptySelection = NO;
	commits.content = selection;
	[commits setSelectedObjects:selection];
	[self.historyController setValue:commits forKey:@"commitController"];

	return commits;
}

- (void)testAContextMenuItemCopiesTheClickedCommitNotTheSelection
{
	PBGitCommit *selected = [[PBGitCommit alloc] init];
	PBGitCommit *clicked = [[PBGitCommit alloc] init];
	[self commitsWithSelection:@[ selected ]];

	NSMenuItem *item = [[NSMenuItem alloc] init];
	item.representedObject = clicked;

	XCTAssertEqualObjects([self.historyController commitsForSender:item], @[ clicked ]);
}

- (void)testAContextMenuItemForSeveralCommitsCopiesThemAll
{
	NSArray *clicked = @[ [[PBGitCommit alloc] init], [[PBGitCommit alloc] init] ];
	[self commitsWithSelection:@[ [[PBGitCommit alloc] init] ]];

	NSMenuItem *item = [[NSMenuItem alloc] init];
	item.representedObject = clicked;

	XCTAssertEqualObjects([self.historyController commitsForSender:item], clicked);
}

// The Edit menu's copy items carry no commit, so they still act on the selection.
- (void)testTheEditMenuStillCopiesTheSelection
{
	NSArray *selection = @[ [[PBGitCommit alloc] init] ];
	[self commitsWithSelection:selection];

	XCTAssertEqualObjects([self.historyController commitsForSender:[[NSMenuItem alloc] init]], selection);
}

- (void)testAKeyboardCopyStillCopiesTheSelection
{
	NSArray *selection = @[ [[PBGitCommit alloc] init] ];
	[self commitsWithSelection:selection];

	XCTAssertEqualObjects([self.historyController commitsForSender:nil], selection);
}

@end
