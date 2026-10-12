//
//  PBGitRepositoryWatcherRefreshTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"
#import "PBGitRepositoryWatcher.h"
#import "PBGitDefaults.h"

// Quiet / max wait are private. Tests set them so a note is delivered on the
// same turn, or so a burst and a capped wait can be observed.
@interface PBGitRepositoryWatcher (RefreshTesting)
@property (nonatomic) NSTimeInterval coalesceInterval;
@property (nonatomic) NSTimeInterval maxCoalesceInterval;
- (BOOL)eventPathsContainInterestingChange:(NSArray *)eventPaths;
@end

@interface PBSyncCountingRepository : PBGitRepository
@property (nonatomic, assign) NSUInteger syncCount;
@end

@implementation PBSyncCountingRepository

- (void)syncWithWorkingTree
{
	self.syncCount++;
}

@end

@interface PBGitRepositoryWatcherRefreshTests : XCTestCase
@property (nonatomic, strong) PBSyncCountingRepository *repository;
@property (nonatomic, strong) PBGitRepositoryWatcher *watcher;
@property (nonatomic, strong) id watcherSettingToPutBack;
@end

@implementation PBGitRepositoryWatcherRefreshTests

- (void)setUp
{
	[super setUp];

	self.watcherSettingToPutBack = [[NSUserDefaults standardUserDefaults] objectForKey:@"PBUseRepositoryWatcher"];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PBUseRepositoryWatcher"];
	XCTAssertFalse([PBGitDefaults useRepositoryWatcher]);

	self.repository = [[PBSyncCountingRepository alloc] init];
	self.watcher = [[PBGitRepositoryWatcher alloc] initWithRepository:self.repository];
}

- (void)tearDown
{
	[self.watcher stop];

	if (self.watcherSettingToPutBack)
		[[NSUserDefaults standardUserDefaults] setObject:self.watcherSettingToPutBack forKey:@"PBUseRepositoryWatcher"];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PBUseRepositoryWatcher"];

	[super tearDown];
}

- (void)testADiskChangeSyncsTheRepository
{
	self.watcher.coalesceInterval = 0;

	[self.watcher noteDiskChanged];

	XCTAssertEqual(self.repository.syncCount, 1u, @"the watcher does not interpret the event; the repository reads git");
}

- (void)testABurstOfDiskChangesIsOneSync
{
	self.watcher.coalesceInterval = 0.05;
	self.watcher.maxCoalesceInterval = 1.0;

	[self.watcher noteDiskChanged];
	[self.watcher noteDiskChanged];
	[self.watcher noteDiskChanged];

	XCTAssertEqual(self.repository.syncCount, 0u, @"nothing is read while the disk is still moving");

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:0.3];
	while (self.repository.syncCount == 0 && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	XCTAssertEqual(self.repository.syncCount, 1u, @"a rebase or a save burst is one read once the tree is quiet");
}

// A watch-mode build that never goes quiet must still sync, or a terminal
// commit made during the build never appears (the #719 symptom again).
- (void)testASteadyStreamOfChangesStillSyncsWithinTheMaxWait
{
	self.watcher.coalesceInterval = 0.2;
	self.watcher.maxCoalesceInterval = 0.35;

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:0.8];
	while (self.repository.syncCount == 0 && [limit timeIntervalSinceNow] > 0) {
		[self.watcher noteDiskChanged];
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
	}

	XCTAssertEqual(self.repository.syncCount, 1u, @"the max wait forces a read even while the tree keeps moving");
}

// GitX runs git as a subprocess, so IgnoreSelf does not cover index.lock. With
// FileEvents the stream names the lock file itself.
- (void)testALockFileAloneIsNotAnInterestingChange
{
	XCTAssertFalse([self.watcher eventPathsContainInterestingChange:@[ @"/tmp/repo/.git/index.lock" ]],
				   @"lock churn from a git subprocess must not start another sync");
}

- (void)testAnIndexWriteBesideItsLockIsInteresting
{
	NSArray *paths = @[ @"/tmp/repo/.git/index.lock", @"/tmp/repo/.git/index" ];

	XCTAssertTrue([self.watcher eventPathsContainInterestingChange:paths],
				  @"the real index write after the lock is what the sync has to see");
}

- (void)testAFolderOnlyPathWithoutFileEventsWouldHaveBeenInteresting
{
	// Regression guard: without FileEvents the stream only reports the folder.
	// That path must still count as interesting once FileEvents is on for other
	// reasons, and must not be mistaken for a lock.
	XCTAssertTrue([self.watcher eventPathsContainInterestingChange:@[ @"/tmp/repo/.git" ]],
				  @"a .git directory event is a real change when no lock path is present");
}

@end
