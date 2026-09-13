//
//  PBGitCommitControllerRefreshTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitCommitController.h"
#import "PBGitIndex.h"
#import "PBGitRepository.h"
#import "PBGitRepositoryWatcher.h"

// Exposes the handler the repository watcher posts into.
@interface PBGitCommitController (RefreshTesting)
- (void)repositoryUpdatedNotification:(NSNotification *)notification;
@end

// Answers for the index file without one on disk, and stays away from git for
// the two refreshes the controller can ask of it.
@interface PBAnsweringIndex : PBGitIndex
@property (nonatomic, assign) BOOL indexWasWritten;
@end

@implementation PBAnsweringIndex

- (BOOL)indexChangedSinceLastRefresh
{
	return self.indexWasWritten;
}

- (void)refresh
{
}

- (void)refreshStatCache
{
}

@end

@interface PBIndexStubRepository : PBGitRepository
@property (nonatomic, strong) PBAnsweringIndex *answeringIndex;
@end

@implementation PBIndexStubRepository

- (PBGitIndex *)index
{
	return self.answeringIndex;
}

- (void)reloadRefs
{
}

@end

// Counts the refreshes the controller decides on, instead of running them.
@interface PBCountingCommitController : PBGitCommitController
@property (nonatomic, assign) NSUInteger refreshCount;
@end

@implementation PBCountingCommitController

- (IBAction)refresh:(id)sender
{
	self.refreshCount++;
}

@end

@interface PBGitCommitControllerRefreshTests : XCTestCase
@property (nonatomic, strong) PBIndexStubRepository *repository;
@property (nonatomic, strong) PBCountingCommitController *controller;
@end

@implementation PBGitCommitControllerRefreshTests

- (void)setUp
{
	[super setUp];

	self.repository = [[PBIndexStubRepository alloc] init];
	self.repository.answeringIndex = [[PBAnsweringIndex alloc] initWithRepository:self.repository];

	self.controller = [[PBCountingCommitController alloc] initWithRepository:self.repository superController:nil];
}

- (void)tearDown
{
	[[NSNotificationCenter defaultCenter] removeObserver:self.controller];

	[super tearDown];
}

- (void)reportEvent:(PBGitRepositoryWatcherEventType)eventType
{
	NSNotification *notification = [NSNotification notificationWithName:PBGitRepositoryEventNotification
																 object:self.repository
															   userInfo:@{kPBGitRepositoryEventTypeUserInfoKey : @(eventType)}];

	[self.controller repositoryUpdatedNotification:notification];
}

- (void)testTheIndexThatWasJustReadIsNotReadAgain
{
	self.repository.answeringIndex.indexWasWritten = NO;

	[self reportEvent:PBGitRepositoryWatcherEventTypeIndex];

	XCTAssertEqual(self.controller.refreshCount, 0, @"an index already read back holds nothing new");
}

- (void)testAnIndexWrittenByAnyoneElseIsRead
{
	self.repository.answeringIndex.indexWasWritten = YES;

	[self reportEvent:PBGitRepositoryWatcherEventTypeIndex];

	XCTAssertEqual(self.controller.refreshCount, 1, @"a commit made in a terminal has to reach the view");
}

- (void)testAWorkingDirectoryEventIsAlwaysRead
{
	self.repository.answeringIndex.indexWasWritten = NO;

	[self reportEvent:PBGitRepositoryWatcherEventTypeWorkingDirectory];

	XCTAssertEqual(self.controller.refreshCount, 1, @"an edited file changes what the diffs say");
}

- (void)testAMovedRefOnItsOwnIsLeftToTheHistoryView
{
	self.repository.answeringIndex.indexWasWritten = YES;

	[self reportEvent:PBGitRepositoryWatcherEventTypeGitDirectory];

	XCTAssertEqual(self.controller.refreshCount, 0, @"the commit view has no refs of its own to reload");
}

@end
