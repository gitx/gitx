//
//  PBGitHistoryWorktreeDoubleClickTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitRef.h"
#import "PBGitWindowController.h"

// The double click asks the table where the mouse went down, which a test
// cannot answer, so the decision it reaches is taken on its own.
@interface PBGitHistoryController (WorktreeDoubleClickTesting)
- (void)actOnDoubleClickedRef:(PBGitRef *)ref;
@end

@interface PBDoubleClickStubRepository : PBGitRepository
@property (nonatomic, copy) NSString *worktreePath;
@property (nonatomic, assign) BOOL checkoutWasAttempted;
@end

@implementation PBDoubleClickStubRepository

- (NSString *)pathOfWorktreeHoldingRef:(PBGitRef *)ref
{
	return self.worktreePath;
}

- (BOOL)isRefHeldByAnotherWorktree:(PBGitRef *)ref
{
	return self.worktreePath != nil;
}

- (BOOL)checkoutRefish:(id<PBGitRefish>)ref error:(NSError **)error
{
	self.checkoutWasAttempted = YES;

	if (error)
		*error = [NSError errorWithDomain:@"test" code:1 userInfo:@{NSLocalizedDescriptionKey : @"checkout failed"}];

	return NO;
}

@end

@interface PBDoubleClickStubWindowController : PBGitWindowController
@property (nonatomic, strong) PBGitRef *worktreeOpenedForRef;
@property (nonatomic, assign) BOOL errorWasShown;
@end

@implementation PBDoubleClickStubWindowController

- (void)openWorktreeHoldingRef:(PBGitRef *)ref
{
	self.worktreeOpenedForRef = ref;
}

- (void)showErrorSheet:(NSError *)error
{
	self.errorWasShown = YES;
}

@end

@interface PBGitHistoryWorktreeDoubleClickTests : XCTestCase
@property (nonatomic, strong) PBDoubleClickStubRepository *repository;
// -windowController is weak, so the stub has to be held here to stay alive.
@property (nonatomic, strong) PBDoubleClickStubWindowController *windowController;
@property (nonatomic, strong) PBGitHistoryController *historyController;
@end

@implementation PBGitHistoryWorktreeDoubleClickTests

- (void)setUp
{
	[super setUp];

	self.repository = [[PBDoubleClickStubRepository alloc] init];
	self.windowController = [[PBDoubleClickStubWindowController alloc] init];
	self.historyController = [[PBGitHistoryController alloc] initWithRepository:self.repository
																superController:self.windowController];
}

// git refuses to check out a branch another worktree holds, so the double click
// used to end in a "checkout failed" sheet. The menu on that same label has
// always offered to open the worktree instead.
- (void)testDoubleClickingABranchHeldElsewhereOpensItsWorktree
{
	self.repository.worktreePath = @"/repos/gitx-feature";

	[self.historyController actOnDoubleClickedRef:[PBGitRef refFromString:@"refs/heads/feature"]];

	XCTAssertEqualObjects(self.windowController.worktreeOpenedForRef.ref, @"refs/heads/feature",
						  @"the worktree holding the branch was not opened");
	XCTAssertFalse(self.repository.checkoutWasAttempted,
				   @"a checkout that cannot succeed should not be attempted");
	XCTAssertFalse(self.windowController.errorWasShown,
				   @"nothing failed, so nothing should be reported");
}

- (void)testDoubleClickingAnOrdinaryBranchStillChecksItOut
{
	self.repository.worktreePath = nil;

	[self.historyController actOnDoubleClickedRef:[PBGitRef refFromString:@"refs/heads/feature"]];

	XCTAssertTrue(self.repository.checkoutWasAttempted, @"an ordinary branch is checked out as before");
	XCTAssertNil(self.windowController.worktreeOpenedForRef);
	XCTAssertTrue(self.windowController.errorWasShown, @"a checkout that fails is still reported");
}

- (void)testADoubleClickAwayFromALabelDoesNothing
{
	self.repository.worktreePath = @"/repos/gitx-feature";

	[self.historyController actOnDoubleClickedRef:nil];

	XCTAssertFalse(self.repository.checkoutWasAttempted);
	XCTAssertNil(self.windowController.worktreeOpenedForRef);
}

@end
