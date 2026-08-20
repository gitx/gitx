//
//  PBGitIndexRefreshTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitIndex.h"
#import "PBGitRepository.h"
#import "PBGitRepository_PBGitBinarySupport.h"
#import "PBChangedFile.h"

// Exposes the refresh bookkeeping and the per-command notification sender, so
// the wiring around a refresh can be driven without a repository or a git
// process, the same way the other suites here reach their seams.
@interface PBGitIndex (RefreshTesting)
- (BOOL)beginRefreshOrDeferIt;
- (BOOL)endRefreshTakingDeferred;
- (void)postIndexRefreshSuccess:(BOOL)success message:(nullable NSString *)message;
@end

// -[PBGitRepository init] only allocates two empty collections and reads one
// default - no libgit2, no working directory, no repository watcher - so a stub
// needs to stand in for nothing more than the one call staging makes.
@interface PBStubRepository : PBGitRepository
@property (nonatomic, assign) BOOL gitAcceptsTheChange;
@property (nonatomic, strong) NSMutableArray<NSArray<NSString *> *> *launchedArguments;
@property (nonatomic, strong) NSMutableArray<NSString *> *launchedInput;
@end

@implementation PBStubRepository

- (instancetype)init
{
	if (!(self = [super init]))
		return nil;

	_gitAcceptsTheChange = YES;
	_launchedArguments = [NSMutableArray array];
	_launchedInput = [NSMutableArray array];

	return self;
}

- (BOOL)launchTaskWithArguments:(nullable NSArray *)arguments input:(nullable NSString *)inputString error:(NSError **)error
{
	[self.launchedArguments addObject:arguments ?: @[]];
	[self.launchedInput addObject:inputString ?: @""];

	return self.gitAcceptsTheChange;
}

@end

// Records the read-back that staging asks for, instead of performing it.
@interface PBRecordingIndex : PBGitIndex
@property (nonatomic, assign) NSUInteger refreshCount;
@end

@implementation PBRecordingIndex

- (void)refresh
{
	self.refreshCount++;
}

@end

static NSString *const kHeadSHA = @"e69de29bb2d1d6434b8b29ae775ad8c2e48c5391";

@interface PBGitIndexRefreshTests : XCTestCase
@property (nonatomic, strong) PBStubRepository *repository;
@property (nonatomic, strong) PBRecordingIndex *gitIndex;
@end

@implementation PBGitIndexRefreshTests

- (void)setUp
{
	[super setUp];

	// The index holds its repository weakly, so the test case owns them both
	self.repository = [[PBStubRepository alloc] init];
	self.gitIndex = [[PBRecordingIndex alloc] initWithRepository:self.repository];
}

- (PBChangedFile *)trackedFile
{
	PBChangedFile *file = [[PBChangedFile alloc] initWithPath:@"a.txt"];
	file.status = MODIFIED;
	file.commitBlobMode = @"100644";
	file.commitBlobSHA = kHeadSHA;

	return file;
}

#pragma mark Staging reads the index back

// The flags set straight after update-index are what git was asked for, not
// what it recorded. A path that has since moved or vanished is staged as a
// deletion, which used to leave the view claiming something git disagreed with
// until the whole application was restarted.
- (void)testStagingAsksGitAndThenReadsTheIndexBack
{
	PBChangedFile *file = [self trackedFile];

	XCTAssertTrue([self.gitIndex stageFiles:@[ file ]]);

	XCTAssertEqualObjects(self.repository.launchedArguments,
						  (@[ @[ @"update-index", @"--add", @"--remove", @"-z", @"--stdin" ] ]));
	XCTAssertTrue(file.hasStagedChanges);
	XCTAssertEqual(self.gitIndex.refreshCount, 1u,
				   @"the flags above are optimistic, so git has to be asked what it actually recorded");
}

- (void)testUnstagingAsksGitAndThenReadsTheIndexBack
{
	PBChangedFile *file = [self trackedFile];

	XCTAssertTrue([self.gitIndex unstageFiles:@[ file ]]);

	XCTAssertEqualObjects(self.repository.launchedArguments,
						  (@[ @[ @"update-index", @"-z", @"--index-info" ] ]));
	NSString *expectedIndexInfo = [NSString stringWithFormat:@"100644 %@\ta.txt", kHeadSHA];
	XCTAssertTrue([self.repository.launchedInput.firstObject hasPrefix:expectedIndexInfo]);
	XCTAssertTrue(file.hasUnstagedChanges);
	XCTAssertEqual(self.gitIndex.refreshCount, 1u);
}

// update-index reads its input NUL-separated, so the terminator is part of the
// contract rather than decoration.
- (void)testStagedPathsReachGitNulTerminated
{
	[self.gitIndex stageFiles:@[ [self trackedFile] ]];

	NSString *input = self.repository.launchedInput.firstObject;
	XCTAssertTrue([input hasPrefix:@"a.txt"]);
	XCTAssertEqual(input.length, 6u);
	XCTAssertEqual([input characterAtIndex:input.length - 1], (unichar)0);
}

// A rejected update-index changed nothing, so there is nothing to read back and
// the failure has to surface rather than be papered over with a refresh.
- (void)testNothingIsReadBackWhenGitRejectedTheChange
{
	self.repository.gitAcceptsTheChange = NO;
	PBChangedFile *file = [self trackedFile];

	XCTAssertFalse([self.gitIndex stageFiles:@[ file ]]);

	XCTAssertEqual(self.repository.launchedArguments.count, 1u);
	XCTAssertFalse(file.hasStagedChanges, @"nothing was staged, so nothing should look staged");
	XCTAssertEqual(self.gitIndex.refreshCount, 0u);
}

#pragma mark A refresh announces the index only once it has been reconciled

// Each of the three commands reports on its own, long before the file list has
// been rebuilt from all three of them. Announcing an index update from there
// served observers the previous refresh's contents.
- (void)testACommandResultDoesNotAnnounceAnIndexUpdate
{
	XCTestExpectation *statusReported = [self expectationForNotification:PBGitIndexIndexRefreshStatus
																	  object:self.gitIndex
																	 handler:nil];
	XCTestExpectation *indexAnnounced = [self expectationForNotification:PBGitIndexIndexUpdated
																	  object:self.gitIndex
																	 handler:nil];
	indexAnnounced.inverted = YES;

	[self.gitIndex postIndexRefreshSuccess:YES message:@"diff-index success"];

	[self waitForExpectations:@[ statusReported, indexAnnounced ] timeout:1.0];
}

- (void)testAFailedCommandDoesNotAnnounceAnIndexUpdateEither
{
	XCTestExpectation *failureReported = [self expectationForNotification:PBGitIndexIndexRefreshFailed
																	   object:self.gitIndex
																	  handler:nil];
	XCTestExpectation *indexAnnounced = [self expectationForNotification:PBGitIndexIndexUpdated
																	  object:self.gitIndex
																	 handler:nil];
	indexAnnounced.inverted = YES;

	[self.gitIndex postIndexRefreshSuccess:NO message:@"diff-index failed"];

	[self waitForExpectations:@[ failureReported, indexAnnounced ] timeout:1.0];
}

#pragma mark Overlapping refreshes coalesce

// A refresh requested while one was running used to be discarded outright.
// Rebasing from a terminal produces a burst of events, so the discarded one was
// most likely the settling event carrying the state the user ends up looking at.
- (void)testARequestArrivingDuringARefreshIsDeferredNotDropped
{
	XCTAssertTrue([self.gitIndex beginRefreshOrDeferIt], @"the first request should run");
	XCTAssertFalse([self.gitIndex beginRefreshOrDeferIt], @"a second request must not run alongside the first");

	XCTAssertTrue([self.gitIndex endRefreshTakingDeferred], @"the deferred request still has to be run");
}

- (void)testABurstOfRequestsCollapsesIntoASingleRerun
{
	XCTAssertTrue([self.gitIndex beginRefreshOrDeferIt]);

	for (NSUInteger i = 0; i < 5; i++)
		XCTAssertFalse([self.gitIndex beginRefreshOrDeferIt]);

	XCTAssertTrue([self.gitIndex endRefreshTakingDeferred], @"a burst is worth exactly one re-run");

	XCTAssertTrue([self.gitIndex beginRefreshOrDeferIt], @"which then runs as an ordinary refresh");
	XCTAssertFalse([self.gitIndex endRefreshTakingDeferred], @"and settles, rather than refreshing forever");
}

- (void)testAnUncontestedRefreshEndsWithoutSchedulingAnother
{
	XCTAssertTrue([self.gitIndex beginRefreshOrDeferIt]);
	XCTAssertFalse([self.gitIndex endRefreshTakingDeferred]);

	XCTAssertTrue([self.gitIndex beginRefreshOrDeferIt], @"the guard has to be clear once a refresh has ended");
}

@end
