//
//  PBGitRepositoryWatcherRefreshTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"
#import "PBGitRepositoryWatcher.h"
#import "PBGitDefaults.h"

// The quiet period is private. Tests set it so a note can be delivered on the
// same turn, or so a burst can be observed before the timer fires.
@interface PBGitRepositoryWatcher (RefreshTesting)
@property (nonatomic) NSTimeInterval coalesceInterval;
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

	[self.watcher noteDiskChanged];
	[self.watcher noteDiskChanged];
	[self.watcher noteDiskChanged];

	XCTAssertEqual(self.repository.syncCount, 0u, @"nothing is read while the disk is still moving");

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:0.3];
	while (self.repository.syncCount == 0 && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	XCTAssertEqual(self.repository.syncCount, 1u, @"a rebase or a save burst is one read once the tree is quiet");
}

// GitX runs git as a subprocess, so IgnoreSelf does not cover index.lock. A
// sync that fed itself through lock churn would never settle (see #164).
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

@end
