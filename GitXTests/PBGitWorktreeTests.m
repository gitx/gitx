//
//  PBGitWorktreeTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitWorktree.h"

// Taken from `git worktree list --porcelain` on git 2.55.0, against a scratch
// repository built to carry every state at once. The bare repository prints on
// its own, since a bare checkout cannot hold linked worktrees.
static NSString *const kPorcelain =
	@"worktree /repos/gitx\n"
	@"HEAD 0000000000000000000000000000000000000001\n"
	@"branch refs/heads/master\n"
	@"\n"
	@"worktree /repos/gitx-detached\n"
	@"HEAD 0000000000000000000000000000000000000002\n"
	@"detached\n"
	@"\n"
	@"worktree /repos/gitx-gone\n"
	@"HEAD 0000000000000000000000000000000000000003\n"
	@"branch refs/heads/gone\n"
	@"prunable gitdir file points to non-existent location\n"
	@"\n"
	@"worktree /repos/gitx-locked\n"
	@"HEAD 0000000000000000000000000000000000000004\n"
	@"branch refs/heads/locked-plain\n"
	@"locked\n"
	@"\n"
	@"worktree /repos/gitx-lockedreason\n"
	@"HEAD 0000000000000000000000000000000000000005\n"
	@"branch refs/heads/locked-reason\n"
	@"locked on an external disk\n";

static NSString *const kBarePorcelain =
	@"worktree /repos/bare.git\n"
	@"bare\n";

@interface PBGitWorktreeTests : XCTestCase
@end

@implementation PBGitWorktreeTests

- (NSArray<PBGitWorktree *> *)worktrees
{
	return [PBGitWorktree worktreesFromPorcelain:kPorcelain currentWorktreeAtPath:nil];
}

- (PBGitWorktree *)worktreeAtPath:(NSString *)path
{
	for (PBGitWorktree *worktree in [self worktrees])
		if ([worktree.path isEqualToString:path])
			return worktree;

	return nil;
}

- (void)testEveryRecordBecomesAWorktree
{
	XCTAssertEqual([self worktrees].count, 5, @"one worktree per record in the porcelain");
}

- (void)testAWorktreeOnABranchCarriesItsHeadAndRef
{
	PBGitWorktree *worktree = [self worktreeAtPath:@"/repos/gitx"];

	XCTAssertEqualObjects(worktree.HEAD, @"0000000000000000000000000000000000000001");
	XCTAssertEqualObjects(worktree.branchRefName, @"refs/heads/master");
	XCTAssertFalse(worktree.isDetached);
	XCTAssertFalse(worktree.isBare);
	XCTAssertFalse(worktree.isLocked);
	XCTAssertFalse(worktree.isPrunable);
}

- (void)testADetachedWorktreeHasAHeadButNoRef
{
	PBGitWorktree *worktree = [self worktreeAtPath:@"/repos/gitx-detached"];

	XCTAssertTrue(worktree.isDetached);
	XCTAssertEqualObjects(worktree.HEAD, @"0000000000000000000000000000000000000002");
	XCTAssertNil(worktree.branchRefName, @"a detached worktree prints no branch line");
}

// The trap this class exists for: a bare record carries neither HEAD nor
// branch, so anything that starts a record at HEAD loses it entirely.
- (void)testABareRepositoryIsReadDespiteHavingNoHead
{
	NSArray<PBGitWorktree *> *worktrees = [PBGitWorktree worktreesFromPorcelain:kBarePorcelain currentWorktreeAtPath:nil];

	XCTAssertEqual(worktrees.count, 1, @"a bare record has no HEAD line and must still be read");
	XCTAssertTrue(worktrees.firstObject.isBare);
	XCTAssertEqualObjects(worktrees.firstObject.path, @"/repos/bare.git");
	XCTAssertNil(worktrees.firstObject.HEAD);
	XCTAssertNil(worktrees.firstObject.branchRefName);
}

- (void)testALockedWorktreeIsReadWithAndWithoutAReason
{
	PBGitWorktree *plain = [self worktreeAtPath:@"/repos/gitx-locked"];
	PBGitWorktree *explained = [self worktreeAtPath:@"/repos/gitx-lockedreason"];

	XCTAssertTrue(plain.isLocked);
	XCTAssertNil(plain.lockReason, @"locked can stand on its own, so there is nothing to report");

	XCTAssertTrue(explained.isLocked);
	XCTAssertEqualObjects(explained.lockReason, @"on an external disk");
}

- (void)testAPrunableWorktreeCarriesTheReasonGitGave
{
	PBGitWorktree *worktree = [self worktreeAtPath:@"/repos/gitx-gone"];

	XCTAssertTrue(worktree.isPrunable);
	XCTAssertEqualObjects(worktree.prunableReason, @"gitdir file points to non-existent location");
}

// git quotes the reason through core.quotePath when it carries anything
// unusual, so the raw remainder of the line is not the reason.
- (void)testAQuotedLockReasonIsUnescaped
{
	NSString *porcelain =
		@"worktree /repos/gitx-quoted\n"
		@"HEAD 0000000000000000000000000000000000000006\n"
		@"branch refs/heads/quoted\n"
		@"locked \"reason\\nwhy is locked\"\n";

	PBGitWorktree *worktree = [PBGitWorktree worktreesFromPorcelain:porcelain currentWorktreeAtPath:nil].firstObject;

	XCTAssertTrue(worktree.isLocked);
	XCTAssertEqualObjects(worktree.lockReason, @"reason\nwhy is locked");
}

// The octal escapes stand for bytes of the UTF-8 encoding, not for characters,
// so decoding them one at a time turns an accented reason into mojibake.
- (void)testAnEscapedReasonDecodesItsBytesAsUTF8
{
	NSString *porcelain =
		@"worktree /repos/gitx-accented\n"
		@"locked \"caf\\303\\251\"\n";

	PBGitWorktree *worktree = [PBGitWorktree worktreesFromPorcelain:porcelain currentWorktreeAtPath:nil].firstObject;

	XCTAssertEqualObjects(worktree.lockReason, @"caf\u00e9");
}

- (void)testOnlyTheWorktreeWeWereGivenIsTheCurrentOne
{
	NSArray<PBGitWorktree *> *worktrees = [PBGitWorktree worktreesFromPorcelain:kPorcelain currentWorktreeAtPath:@"/repos/gitx"];

	for (PBGitWorktree *worktree in worktrees)
		XCTAssertEqual(worktree.isCurrent, [worktree.path isEqualToString:@"/repos/gitx"],
					   @"%@ answered the wrong way about being ours", worktree.path);
}

- (void)testNoWorktreeIsCurrentWhenWeNameNone
{
	for (PBGitWorktree *worktree in [self worktrees])
		XCTAssertFalse(worktree.isCurrent, @"%@ claimed to be ours with no path given", worktree.path);
}

// The repository compares a fresh snapshot against the last one to decide
// whether to tell anyone, and the history list polls, so value equality is what
// keeps a poll that found nothing new from reloading the sidebar.
- (void)testTwoReadsOfOneRepositoryCompareEqual
{
	XCTAssertEqualObjects([PBGitWorktree worktreesFromPorcelain:kPorcelain currentWorktreeAtPath:@"/repos/gitx"],
						  [PBGitWorktree worktreesFromPorcelain:kPorcelain currentWorktreeAtPath:@"/repos/gitx"],
						  @"the same output read twice has to compare equal, or every poll looks like a change");
}

- (void)testAWorktreeThatChangedStateDoesNotCompareEqual
{
	NSString *unlocked =
		@"worktree /repos/gitx-locked\n"
		@"HEAD 0000000000000000000000000000000000000004\n"
		@"branch refs/heads/locked-plain\n";
	NSString *locked = [unlocked stringByAppendingString:@"locked\n"];

	XCTAssertNotEqualObjects([PBGitWorktree worktreesFromPorcelain:unlocked currentWorktreeAtPath:nil],
							 [PBGitWorktree worktreesFromPorcelain:locked currentWorktreeAtPath:nil],
							 @"locking a worktree has to read as a change");
}

- (void)testTheFirstRecordIsTheMainWorktree
{
	NSArray<PBGitWorktree *> *worktrees = [self worktrees];

	XCTAssertTrue(worktrees.firstObject.isMain, @"git always lists the main worktree first");
	for (PBGitWorktree *worktree in [worktrees subarrayWithRange:NSMakeRange(1, worktrees.count - 1)])
		XCTAssertFalse(worktree.isMain, @"%@", worktree);
}

- (void)testABareRepositoryIsItsOwnMainWorktree
{
	NSArray<PBGitWorktree *> *worktrees = [PBGitWorktree worktreesFromPorcelain:kBarePorcelain currentWorktreeAtPath:nil];

	XCTAssertTrue(worktrees.firstObject.isMain);
}

- (void)testEmptyOutputReadsAsNoWorktrees
{
	XCTAssertEqualObjects([PBGitWorktree worktreesFromPorcelain:@"" currentWorktreeAtPath:nil], @[]);
}

@end
