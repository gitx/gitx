//
//  PBWebHistoryControllerCurrentRefTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBWebHistoryController.h"
#import "PBGitRepository.h"

// The details pane asks the repository which branch is current every time it
// shows a commit it has not shown before, so the answer is named here the same
// way the other suites name the seams they drive.
@interface PBWebHistoryController (PBCurrentRefTests)
+ (NSString *)nameOfCurrentRefIn:(PBGitRepository *)repository;
@end

@interface PBWebHistoryControllerCurrentRefTests : XCTestCase
@end

@implementation PBWebHistoryControllerCurrentRefTests

// A repository whose HEAD cannot be read answers nil, which is what a window
// left open over a checkout that has been removed or unmounted ends up holding.
- (PBGitRepository *)repositoryWithNoReadableHead
{
	PBGitRepository *repository = [[PBGitRepository alloc] init];
	XCTAssertNil([repository headRef], @"the fixture has to have no readable head for this to be the case under test");

	return repository;
}

- (void)testARepositoryWithNoReadableHeadNamesNoCurrentRefRatherThanNil
{
	XCTAssertEqualObjects([PBWebHistoryController nameOfCurrentRefIn:[self repositoryWithNoReadableHead]], @"");
}

// The name goes straight into the argument list the page is called with, and a
// nil there aborts the application rather than leaving the pane blank.
- (void)testTheArgumentsForACommitCanBeBuiltWhenHeadCannotBeRead
{
	PBGitRepository *repository = [self repositoryWithNoReadableHead];

	XCTAssertNoThrow((void)(@[ @"commit", [PBWebHistoryController nameOfCurrentRefIn:repository], @[] ]));
}

@end
