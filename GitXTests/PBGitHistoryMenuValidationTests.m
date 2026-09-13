//
//  PBGitHistoryMenuValidationTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitCommit.h"

// Menu validation is an informal protocol, so the test names the method it
// exercises.
@interface PBGitHistoryController (MenuValidationTesting)
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem;
@end

// The Edit menu's copy items are validated by the history controller, which
// reads the selection the items act on.
@interface PBGitHistoryMenuValidationTests : XCTestCase
@property (nonatomic, strong) PBGitRepository *repository;
@property (nonatomic, strong) PBGitHistoryController *historyController;
@end

@implementation PBGitHistoryMenuValidationTests

- (void)setUp
{
	[super setUp];

	// Neither the repository nor the controller reaches for libgit2 or the
	// nib until the view is asked for, which these tests never do.
	self.repository = [[PBGitRepository alloc] init];
	self.historyController = [[PBGitHistoryController alloc] initWithRepository:self.repository superController:nil];
}

- (void)selectCommits:(NSArray *)commits
{
	NSArrayController *commitController = [[NSArrayController alloc] init];
	commitController.avoidsEmptySelection = NO;
	commitController.content = commits;
	[commitController setSelectedObjects:commits];
	[self.historyController setValue:commitController forKey:@"commitController"];
}

- (NSArray<NSMenuItem *> *)copyMenuItems
{
	NSMutableArray *items = [NSMutableArray array];
	for (NSString *selectorName in @[ @"copy:", @"copySHA:", @"copyShortName:", @"copyPatch:" ]) {
		NSMenuItem *item = [[NSMenuItem alloc] init];
		item.action = NSSelectorFromString(selectorName);
		[items addObject:item];
	}

	return items;
}

// The bug: the copy items stayed enabled with nothing selected, so choosing one
// silently copied nothing.
- (void)testTheCopyItemsAreOffWithNothingSelected
{
	[self selectCommits:@[]];

	for (NSMenuItem *item in [self copyMenuItems])
		XCTAssertFalse([self.historyController validateMenuItem:item], @"%@", NSStringFromSelector(item.action));
}

- (void)testTheCopyItemsAreOnWithACommitSelected
{
	[self selectCommits:@[ [[PBGitCommit alloc] init] ]];

	for (NSMenuItem *item in [self copyMenuItems])
		XCTAssertTrue([self.historyController validateMenuItem:item], @"%@", NSStringFromSelector(item.action));
}

@end
