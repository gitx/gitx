//
//  PBGitIndexReconcileTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitIndex.h"
#import "PBChangedFile.h"

// Exposes the reconcile step so it can be driven with literal git output,
// without a repository, FSEvents or a git process.
@interface PBGitIndex (ReconcileTesting)
+ (void)reconcileFiles:(NSMutableArray<PBChangedFile *> *)files
				staged:(NSDictionary *)staged
			  unstaged:(NSDictionary *)unstaged
			 untracked:(NSDictionary *)untracked;
@end

static NSString *const kZeroSHA = @"0000000000000000000000000000000000000000";
static NSString *const kHeadSHA = @"e69de29bb2d1d6434b8b29ae775ad8c2e48c5391";
static NSString *const kIndexSHA = @"5716ca5987cbf97d6bb54920bea6adde242d87e6";

@interface PBGitIndexReconcileTests : XCTestCase
@end

@implementation PBGitIndexReconcileTests

#pragma mark Fixtures

// Matches what -dictionaryForLines: builds from git's raw diff output
static NSDictionary *diff(NSString *path, NSString *rawStatus)
{
	if (!path)
		return @{};

	return @{path : [rawStatus componentsSeparatedByString:@" "]};
}

// ls-files --others carries no index information, so PBGitIndex fakes a status
static NSDictionary *others(NSString *path)
{
	if (!path)
		return @{};

	return @{path : @[ @":000000", @"100644", kZeroSHA, kZeroSHA, @"A" ]};
}

static NSDictionary *stagedAdd(NSString *path)
{
	return diff(path, [NSString stringWithFormat:@":000000 100644 %@ %@ A", kZeroSHA, kIndexSHA]);
}

static NSDictionary *stagedModification(NSString *path)
{
	return diff(path, [NSString stringWithFormat:@":100644 100644 %@ %@ M", kHeadSHA, kIndexSHA]);
}

static NSDictionary *stagedDeletion(NSString *path)
{
	return diff(path, [NSString stringWithFormat:@":100644 000000 %@ %@ D", kHeadSHA, kZeroSHA]);
}

static NSDictionary *unstagedModification(NSString *path)
{
	return diff(path, [NSString stringWithFormat:@":100644 100644 %@ %@ M", kIndexSHA, kZeroSHA]);
}

- (PBChangedFile *)fileForPath:(NSString *)path in:(NSArray<PBChangedFile *> *)files
{
	for (PBChangedFile *file in files)
		if ([file.path isEqualToString:path])
			return file;

	return nil;
}

- (void)reconcile:(NSMutableArray *)files
		   staged:(NSDictionary *)staged
		 unstaged:(NSDictionary *)unstaged
		untracked:(NSDictionary *)untracked
{
	[PBGitIndex reconcileFiles:files staged:staged unstaged:unstaged untracked:untracked];
}

- (void)reconcileCleanRepository:(NSMutableArray *)files
{
	// Three passes, because a phantom that survives one refresh survives all of them
	for (NSUInteger i = 0; i < 3; i++)
		[self reconcile:files staged:@{} unstaged:@{} untracked:@{}];
}

#pragma mark Regressions

// A file that is untracked and then gets staged is reported by diff-index with
// an all-zero source SHA. Recording that as a real blob used to leave the entry
// with status NEW and a non-nil commitBlobSHA, a combination no refresh could
// clear, so the row outlived the change it stood for until GitX was relaunched.
- (void)testStagedNewFileIsRetiredOnceTheRepositoryIsClean
{
	NSMutableArray *files = [NSMutableArray array];

	[self reconcile:files staged:@{} unstaged:@{} untracked:others(@"new.txt")];
	XCTAssertEqual(files.count, 1u, @"an untracked file should show up");

	[self reconcile:files staged:stagedAdd(@"new.txt") unstaged:@{} untracked:@{}];
	XCTAssertEqual(files.count, 1u, @"staging it should keep exactly one entry");
	XCTAssertNil([self fileForPath:@"new.txt" in:files].commitBlobSHA,
				 @"a path absent from HEAD has no blob, and must not record git's all-zero SHA as one");

	[self reconcileCleanRepository:files];
	XCTAssertEqual(files.count, 0u, @"the entry must not survive a clean working tree");
}

// A tracked path shows up in ls-files --others whenever the index momentarily
// lacks it, which is exactly the window a rebase's index rewrite opens. That
// used to set status to NEW while keeping the blob SHA from the earlier tracked
// pass - the same unclearable combination, reached from the other side.
- (void)testFileSeenAsUntrackedIsRetiredOnceTheRepositoryIsClean
{
	NSMutableArray *files = [NSMutableArray array];

	[self reconcile:files staged:@{} unstaged:unstagedModification(@"old.txt") untracked:@{}];
	XCTAssertEqualObjects([self fileForPath:@"old.txt" in:files].commitBlobSHA, kIndexSHA);

	[self reconcile:files staged:@{} unstaged:@{} untracked:others(@"old.txt")];
	XCTAssertEqual(files.count, 1u);
	XCTAssertNil([self fileForPath:@"old.txt" in:files].commitBlobSHA,
				 @"a path reported as untracked has no index entry to carry a blob");

	[self reconcileCleanRepository:files];
	XCTAssertEqual(files.count, 0u, @"the entry must not survive a clean working tree");
}

// The three git commands finish in whatever order they finish in. Reconciling
// from the full picture means the result is a function of the git output alone,
// so whatever state a previous refresh left behind cannot change it.
- (void)testResultIsIndependentOfPriorState
{
	NSDictionary *staged = stagedModification(@"a.txt");
	NSDictionary *unstaged = unstagedModification(@"b.txt");
	NSDictionary *untracked = others(@"c.txt");

	NSMutableArray *fromScratch = [NSMutableArray array];
	[self reconcile:fromScratch staged:staged unstaged:unstaged untracked:untracked];

	// Reach the same refresh through a messy history instead
	NSMutableArray *afterHistory = [NSMutableArray array];
	[self reconcile:afterHistory staged:@{} unstaged:@{} untracked:others(@"a.txt")];
	[self reconcile:afterHistory staged:stagedAdd(@"a.txt") unstaged:@{} untracked:others(@"b.txt")];
	[self reconcile:afterHistory staged:stagedDeletion(@"c.txt") unstaged:@{} untracked:@{}];
	[self reconcile:afterHistory staged:staged unstaged:unstaged untracked:untracked];

	XCTAssertEqual(fromScratch.count, afterHistory.count);

	for (PBChangedFile *expected in fromScratch) {
		PBChangedFile *actual = [self fileForPath:expected.path in:afterHistory];
		XCTAssertNotNil(actual, @"%@ should be present regardless of prior state", expected.path);
		XCTAssertEqual(actual.status, expected.status, @"%@ status", expected.path);
		XCTAssertEqual(actual.hasStagedChanges, expected.hasStagedChanges, @"%@ staged", expected.path);
		XCTAssertEqual(actual.hasUnstagedChanges, expected.hasUnstagedChanges, @"%@ unstaged", expected.path);
		XCTAssertEqualObjects(actual.commitBlobSHA, expected.commitBlobSHA, @"%@ blob", expected.path);
	}
}

#pragma mark Reported state

- (void)testUntrackedFileIsNewAndUnstaged
{
	NSMutableArray *files = [NSMutableArray array];
	[self reconcile:files staged:@{} unstaged:@{} untracked:others(@"new.txt")];

	PBChangedFile *file = [self fileForPath:@"new.txt" in:files];
	XCTAssertEqual(file.status, NEW);
	XCTAssertFalse(file.hasStagedChanges);
	XCTAssertTrue(file.hasUnstagedChanges);
	XCTAssertNil(file.commitBlobSHA);
}

- (void)testStagedModificationKeepsTheHeadBlobForUnstaging
{
	NSMutableArray *files = [NSMutableArray array];
	[self reconcile:files staged:stagedModification(@"a.txt") unstaged:@{} untracked:@{}];

	PBChangedFile *file = [self fileForPath:@"a.txt" in:files];
	XCTAssertEqual(file.status, MODIFIED);
	XCTAssertTrue(file.hasStagedChanges);
	XCTAssertFalse(file.hasUnstagedChanges);
	XCTAssertEqualObjects(file.commitBlobSHA, kHeadSHA, @"unstaging has to restore HEAD's blob, not the index's");
	XCTAssertEqualObjects(file.commitBlobMode, @"100644");
}

- (void)testStagedDeletionKeepsItsBlob
{
	NSMutableArray *files = [NSMutableArray array];
	[self reconcile:files staged:stagedDeletion(@"gone.txt") unstaged:@{} untracked:@{}];

	PBChangedFile *file = [self fileForPath:@"gone.txt" in:files];
	XCTAssertEqual(file.status, DELETED);
	XCTAssertTrue(file.hasStagedChanges);
	XCTAssertEqualObjects(file.commitBlobSHA, kHeadSHA);
}

// A file staged as new and then edited again appears in both diff outputs. The
// staged side has to win, because -performStageOrUnstage: keys off status NEW
// to write the empty index entry that unstaging an added path needs.
- (void)testPartiallyStagedNewFileKeepsBothFlagsAndStaysNew
{
	NSMutableArray *files = [NSMutableArray array];
	[self reconcile:files
			 staged:stagedAdd(@"a.txt")
		   unstaged:unstagedModification(@"a.txt")
		  untracked:@{}];

	PBChangedFile *file = [self fileForPath:@"a.txt" in:files];
	XCTAssertEqual(files.count, 1u, @"one path is one entry, however many diffs mention it");
	XCTAssertEqual(file.status, NEW);
	XCTAssertTrue(file.hasStagedChanges);
	XCTAssertTrue(file.hasUnstagedChanges);
	XCTAssertNil(file.commitBlobSHA);
}

- (void)testEntryIsReusedAcrossRefreshesForTheSamePath
{
	NSMutableArray *files = [NSMutableArray array];
	[self reconcile:files staged:@{} unstaged:unstagedModification(@"a.txt") untracked:@{}];
	PBChangedFile *original = [self fileForPath:@"a.txt" in:files];

	[self reconcile:files staged:stagedModification(@"a.txt") unstaged:@{} untracked:@{}];

	XCTAssertTrue(original == [self fileForPath:@"a.txt" in:files],
				  @"replacing the object would drop the table's selection on every refresh");
}

- (void)testUnrelatedPathsAreLeftAlone
{
	NSMutableArray *files = [NSMutableArray array];
	[self reconcile:files staged:stagedModification(@"a.txt") unstaged:@{} untracked:others(@"b.txt")];
	XCTAssertEqual(files.count, 2u);

	[self reconcile:files staged:stagedModification(@"a.txt") unstaged:@{} untracked:@{}];

	XCTAssertEqual(files.count, 1u, @"only the path git stopped reporting should go");
	XCTAssertNotNil([self fileForPath:@"a.txt" in:files]);
}

@end
