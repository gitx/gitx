//
//  PBGitRefMenuCopyTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitRef.h"
#import "PBGitWindowController.h"
#import "PBGitWorktree.h"

// The sidebar and the ref labels in the history view are both handed the menu
// this builds, so what it offers is what both of them show.
@interface PBCopyStubRepository : PBGitRepository
@property (nonatomic, copy) NSString *worktreePath;
@property (nonatomic, strong) PBGitWorktree *worktree;
@end

@implementation PBCopyStubRepository

- (NSString *)pathOfWorktreeHoldingRef:(PBGitRef *)ref
{
	return self.worktreePath;
}

- (PBGitWorktree *)worktreeHoldingRef:(PBGitRef *)ref
{
	return self.worktree;
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

@interface PBGitRefMenuCopyTests : XCTestCase
@property (nonatomic, strong) PBCopyStubRepository *repository;
@property (nonatomic, strong) PBGitHistoryController *historyController;
@end

@implementation PBGitRefMenuCopyTests

- (void)setUp
{
	[super setUp];

	self.repository = [[PBCopyStubRepository alloc] init];
	self.historyController = [[PBGitHistoryController alloc] initWithRepository:self.repository superController:nil];
}

- (NSMenuItem *)copyItemForRef:(NSString *)ref
{
	for (NSMenuItem *item in [self.historyController menuItemsForRef:[PBGitRef refFromString:ref]])
		if (item.action == @selector(copyRefName:))
			return item;

	return nil;
}

- (void)testTheMenuOffersToCopyABranchName
{
	NSMenuItem *copy = [self copyItemForRef:@"refs/heads/feature"];

	XCTAssertNotNil(copy, @"the menu offers no way to copy a branch name");
	XCTAssertTrue(copy.isEnabled, @"copying a name cannot fail, so it is never disabled");
	// PBGitRef does not compare by value, so the ref it carries answers by name.
	XCTAssertEqualObjects([(PBGitRef *)copy.representedObject ref], @"refs/heads/feature",
						  @"the item has to carry the ref, or the action cannot tell what to copy");
}

// What goes on the clipboard is what the row shows, which is what you paste
// into a git command; the full ref would have to be trimmed by hand.
- (void)testTheNameOfferedIsTheShortOneRatherThanTheFullRef
{
	NSMenuItem *copy = [self copyItemForRef:@"refs/heads/pu/pb/sidebar"];

	XCTAssertTrue([copy.title hasPrefix:@"Copy name"], @"the title has to say what is copied: %@", copy.title);
	XCTAssertTrue([copy.title containsString:@"pu/pb/sidebar"], @"%@", copy.title);
	XCTAssertFalse([copy.title containsString:@"refs/heads"], @"%@", copy.title);
}

- (void)testATagAndARemoteBranchAreOfferedTheSameWay
{
	XCTAssertNotNil([self copyItemForRef:@"refs/tags/v1.0"], @"a tag name is worth copying too");
	XCTAssertNotNil([self copyItemForRef:@"refs/remotes/origin/feature"], @"a remote branch name is worth copying too");
}

- (NSUInteger)indexOfCopyItemIn:(NSArray<NSMenuItem *> *)items
{
	return [items indexOfObjectPassingTest:^BOOL(NSMenuItem *item, NSUInteger index, BOOL *stop) {
		return item.action == @selector(copyRefName:);
	}];
}

// It used to sit directly above Remove, where reaching for one easily hits the
// other, so it belongs at the top beside the entry that opens or checks out.
- (void)testTheItemSitsSecondWellClearOfTheDestructiveEntries
{
	NSArray<NSMenuItem *> *items = [self.historyController menuItemsForRef:[PBGitRef refFromString:@"refs/heads/feature"]];
	NSUInteger copyIndex = [self indexOfCopyItemIn:items];
	NSUInteger removeIndex = [items indexOfObjectPassingTest:^BOOL(NSMenuItem *item, NSUInteger index, BOOL *stop) {
		return [item.title hasPrefix:@"Remove"];
	}];

	XCTAssertEqual(copyIndex, 1u, @"%@", [items valueForKey:@"title"]);
	XCTAssertTrue(items.firstObject.action == @selector(checkout:), @"%@", items.firstObject.title);
	XCTAssertNotEqual(removeIndex, NSNotFound, @"the entry it must not neighbour is missing from this menu");
	XCTAssertGreaterThan(removeIndex, copyIndex + 1, @"copy and remove must not be neighbours");
}

- (void)testItStaysSecondWhenTheFirstEntryOpensAWorktree
{
	[self.historyController setValue:@"2.50.1" forKey:@"gitVersion"];
	self.repository.worktreePath = @"/repos/gitx-feature";
	self.repository.worktree = [PBGitWorktree worktreesFromPorcelain:@"worktree /repos/gitx\nbare\n\nworktree /repos/gitx-feature\nHEAD 0000000000000000000000000000000000000002\nbranch refs/heads/feature\n" currentWorktreeAtPath:@"/repos/gitx"].lastObject;

	NSArray<NSMenuItem *> *items = [self.historyController menuItemsForRef:[PBGitRef refFromString:@"refs/heads/feature"]];

	XCTAssertTrue(items.firstObject.action == @selector(openWorktree:), @"%@", items.firstObject.title);
	XCTAssertEqual([self indexOfCopyItemIn:items], 1u, @"%@", [items valueForKey:@"title"]);
	XCTAssertTrue(items[2].isSeparatorItem, @"the worktree actions start a group of their own: %@", [items valueForKey:@"title"]);
}

// A remote has no entry to open or check out, so the copy leads the menu there.
- (void)testItComesFirstForARemote
{
	NSArray<NSMenuItem *> *items = [self.historyController menuItemsForRef:[PBGitRef refFromString:@"refs/remotes/origin"]];

	XCTAssertEqual([self indexOfCopyItemIn:items], 0u, @"%@", [items valueForKey:@"title"]);
}

@end
