//
//  PBGitHistoryCommitMenuTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitCommit.h"

// -menuItemsForCommits: only reads a handful of properties off the commit
// (subject, OID, repository, isOnHeadBranch), none of which need a real
// GTCommit or a repository on disk to back them, so this stub overrides just
// those getters instead of going through -initWithRepository:andCommit:.
@interface PBMenuTestCommit : PBGitCommit
@property (nonatomic, copy) NSString *stubSubject;
@property (nonatomic, strong) GTOID *stubOID;
@property (nonatomic, weak) PBGitRepository *stubRepository;
@property (nonatomic, assign) BOOL stubIsOnHeadBranch;
@end

@implementation PBMenuTestCommit

- (instancetype)init
{
	return [super init];
}

- (NSString *)subject
{
	return self.stubSubject;
}

- (GTOID *)OID
{
	return self.stubOID;
}

- (PBGitRepository *)repository
{
	return self.stubRepository;
}

- (BOOL)isOnHeadBranch
{
	return self.stubIsOnHeadBranch;
}

@end

@interface PBGitHistoryCommitMenuTests : XCTestCase
@property (nonatomic, strong) PBGitRepository *repository;
@property (nonatomic, strong) PBGitHistoryController *historyController;
@end

@implementation PBGitHistoryCommitMenuTests

- (void)setUp
{
	[super setUp];

	// -[PBGitRepository init] stays in memory: no libgit2, no repository on
	// disk. Its headRef/headOID both come back nil, which every property
	// -menuItemsForCommits: reaches through it tolerates.
	self.repository = [[PBGitRepository alloc] init];
	self.historyController = [[PBGitHistoryController alloc] initWithRepository:self.repository superController:nil];
}

- (PBMenuTestCommit *)commitWithSubject:(NSString *)subject
{
	PBMenuTestCommit *commit = [PBMenuTestCommit new];
	commit.stubSubject = subject;
	commit.stubOID = [GTOID oidWithSHA:@"8031ee6a0000000000000000000000000000beef"];
	commit.stubRepository = self.repository;
	commit.stubIsOnHeadBranch = NO;

	return commit;
}

- (NSMenuItem *)checkoutCommitItemForCommits:(NSArray<PBGitCommit *> *)commits
{
	NSArray<NSMenuItem *> *items = [self.historyController menuItemsForCommits:commits];

	for (NSMenuItem *item in items) {
		if (item.action == @selector(checkout:))
			return item;
	}
	return nil;
}

#pragma mark The Checkout Commit title names the commit it will check out

- (void)testAShortSubjectAppearsInFullWithNoIndicator
{
	PBMenuTestCommit *commit = [self commitWithSubject:@"Fix the crash"];

	NSMenuItem *item = [self checkoutCommitItemForCommits:@[ commit ]];

	XCTAssertEqualObjects(item.title, @"Checkout Commit “Fix the crash”");
}

- (void)testASubjectLongerThan40CharactersIsTruncatedWithAnIndicator
{
	PBMenuTestCommit *commit = [self commitWithSubject:@"Find the git that Homebrew installed for Apple Silicon"];

	NSMenuItem *item = [self checkoutCommitItemForCommits:@[ commit ]];

	XCTAssertEqualObjects(item.title, @"Checkout Commit “Find the git that Homebrew installed for...”");
}

- (void)testASubjectOfExactly40CharactersIsNotTruncated
{
	NSString *subject = [@"x" stringByPaddingToLength:40 withString:@"x" startingAtIndex:0];
	PBMenuTestCommit *commit = [self commitWithSubject:subject];

	NSMenuItem *item = [self checkoutCommitItemForCommits:@[ commit ]];

	NSString *expected = [NSString stringWithFormat:@"Checkout Commit “%@”", subject];
	XCTAssertEqualObjects(item.title, expected);
}

- (void)testAnEmptyMessageShowsAPlaceholderRatherThanNull
{
	PBMenuTestCommit *commit = [self commitWithSubject:@""];

	NSMenuItem *item = [self checkoutCommitItemForCommits:@[ commit ]];

	XCTAssertEqualObjects(item.title, @"Checkout Commit “<empty message>”");
	XCTAssertFalse([item.title containsString:@"(null)"]);
}

- (void)testTheCheckoutCommitItemIsOmittedForAMultiCommitSelection
{
	PBMenuTestCommit *first = [self commitWithSubject:@"First commit"];
	PBMenuTestCommit *second = [self commitWithSubject:@"Second commit"];

	NSMenuItem *item = [self checkoutCommitItemForCommits:@[ first, second ]];

	XCTAssertNil(item);
}

@end
