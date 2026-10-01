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

	XCTAssertEqualObjects(item.title, @"Checkout TEST “Fix the crash”");
}

- (void)testASubjectLongerThan40CharactersIsTruncatedWithAnIndicator
{
	PBMenuTestCommit *commit = [self commitWithSubject:@"Find the git that Homebrew installed for Apple Silicon"];

	NSMenuItem *item = [self checkoutCommitItemForCommits:@[ commit ]];

	XCTAssertEqualObjects(item.title, @"Checkout TEST “Find the git that Homebrew installed for...”");
}

// The 40-character figure quoted to the user is the number of subject
// characters guaranteed to be kept; the actual untruncated/truncated boundary
// in -truncateToLength:mode:indicator: is 43 vs. 44, since the call passes
// 40 + "...".length as the target length and truncateToLength: only kicks in
// once the string is strictly longer than that target.
- (void)testASubjectOfExactly43CharactersIsNotTruncated
{
	NSString *subject = [@"x" stringByPaddingToLength:43 withString:@"x" startingAtIndex:0];
	PBMenuTestCommit *commit = [self commitWithSubject:subject];

	NSMenuItem *item = [self checkoutCommitItemForCommits:@[ commit ]];

	NSString *expected = [NSString stringWithFormat:@"Checkout TEST “%@”", subject];
	XCTAssertEqualObjects(item.title, expected);
}

- (void)testASubjectOfExactly44CharactersIsTruncated
{
	NSString *subject = [@"x" stringByPaddingToLength:44 withString:@"x" startingAtIndex:0];
	PBMenuTestCommit *commit = [self commitWithSubject:subject];

	NSMenuItem *item = [self checkoutCommitItemForCommits:@[ commit ]];

	NSString *expectedPrefix = [subject substringToIndex:40];
	NSString *expected = [NSString stringWithFormat:@"Checkout TEST “%@...”", expectedPrefix];
	XCTAssertEqualObjects(item.title, expected);
}

- (void)testAnEmptyMessageShowsAPlaceholderRatherThanNull
{
	PBMenuTestCommit *commit = [self commitWithSubject:@""];

	NSMenuItem *item = [self checkoutCommitItemForCommits:@[ commit ]];

	XCTAssertEqualObjects(item.title, @"Checkout TEST “<empty message>”");
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
