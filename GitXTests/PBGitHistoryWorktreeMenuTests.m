//
//  PBGitHistoryWorktreeMenuTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitRef.h"
#import "PBGitWindowController.h"

// The menu is built from what the repository knows, so the test answers for
// the repository instead of opening one.
@interface PBWorktreeStubRepository : PBGitRepository
@property (nonatomic, copy) NSString *worktreePath;
@end

@implementation PBWorktreeStubRepository

- (NSString *)pathOfWorktreeHoldingRef:(PBGitRef *)ref
{
	return self.worktreePath;
}

- (PBGitRevSpecifier *)headRef
{
	return nil;
}

- (BOOL)isRefOnHeadBranch:(PBGitRef *)testRef
{
	return NO;
}

- (PBGitRef *)remoteRefForBranch:(PBGitRef *)branch error:(NSError **)error
{
	return nil;
}

- (NSArray *)remotes
{
	return @[];
}

@end

@interface PBGitHistoryWorktreeMenuTests : XCTestCase
@property (nonatomic, strong) PBWorktreeStubRepository *repository;
@property (nonatomic, strong) PBGitHistoryController *historyController;
@end

@implementation PBGitHistoryWorktreeMenuTests

- (void)setUp
{
	[super setUp];

	self.repository = [[PBWorktreeStubRepository alloc] init];
	self.historyController = [[PBGitHistoryController alloc] initWithRepository:self.repository superController:nil];
}

- (NSMenuItem *)itemForAction:(SEL)action inMenuForBranch:(NSString *)branch
{
	for (NSMenuItem *item in [self.historyController menuItemsForRef:[PBGitRef refFromString:branch]])
		if (item.action == action)
			return item;

	return nil;
}

// A disabled item is built without its action, which is what keeps it from
// firing wherever the menu is shown, so it answers to its title instead.
- (NSMenuItem *)itemTitled:(NSString *)text inMenuForBranch:(NSString *)branch
{
	for (NSMenuItem *item in [self.historyController menuItemsForRef:[PBGitRef refFromString:branch]])
		if ([item.title containsString:text])
			return item;

	return nil;
}

// The bug (#629): git refuses to check out a branch another worktree holds, and
// removing it through `update-ref -d` leaves that worktree on a branch that is
// no longer there. Both are decided before the menu is shown.
- (void)testABranchHeldElsewhereOffersItsWorktreeRatherThanCheckout
{
	self.repository.worktreePath = @"/repos/gitx-feature";

	NSMenuItem *open = [self itemForAction:@selector(openWorktree:) inMenuForBranch:@"refs/heads/feature"];

	XCTAssertNotNil(open);
	XCTAssertNil([self itemForAction:@selector(checkout:) inMenuForBranch:@"refs/heads/feature"]);

	// A branch is in one worktree and no more, so naming the branch names the
	// worktree; the path, which need not be recognisable, is in the tooltip.
	XCTAssertTrue([open.title containsString:@"feature"], @"%@", open.title);
	XCTAssertEqualObjects(open.toolTip, @"/repos/gitx-feature");
}

// Left in place rather than left out, so the entry does not go missing from
// under a reader who knows it should be there.
- (void)testABranchHeldElsewhereOffersRemoveDisabledAndSaysWhy
{
	self.repository.worktreePath = @"/repos/gitx-feature";

	NSMenuItem *remove = [self itemTitled:@"Remove" inMenuForBranch:@"refs/heads/feature"];

	XCTAssertNotNil(remove);
	XCTAssertFalse(remove.isEnabled);
	XCTAssertTrue(remove.action == NULL);
	XCTAssertTrue([remove.toolTip containsString:@"/repos/gitx-feature"], @"%@", remove.toolTip);
}

- (void)testAnOrdinaryBranchIsUnchanged
{
	self.repository.worktreePath = nil;

	XCTAssertNotNil([self itemForAction:@selector(checkout:) inMenuForBranch:@"refs/heads/feature"]);
	XCTAssertTrue([self itemForAction:@selector(deleteRef:) inMenuForBranch:@"refs/heads/feature"].isEnabled);
	XCTAssertNil([self itemForAction:@selector(openWorktree:) inMenuForBranch:@"refs/heads/feature"]);
}

@end
