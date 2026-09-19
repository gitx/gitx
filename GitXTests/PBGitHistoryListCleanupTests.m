//
//  PBGitHistoryListCleanupTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitHistoryList.h"

@interface PBGitHistoryListCleanupTests : XCTestCase
@end

@implementation PBGitHistoryListCleanupTests

// -cleanup cancels the walk and the graph queue, and cancelled operations never
// run the completion blocks that would have called -finishedGraphing. A list
// that has been told to stop is not updating any more, so it has to say so:
// anything waiting for the flag to clear is otherwise waiting for a callback
// that is never coming. The flag is set by hand here because the invariant is
// about what -cleanup leaves behind, not about how the walk got started.
- (void)testACleanedUpListReportsThatItHasStoppedUpdating
{
	PBGitHistoryList *list = [[PBGitHistoryList alloc] initWithRepository:nil];

	list.isUpdating = YES;
	[list cleanup];

	XCTAssertFalse(list.isUpdating, @"a list that was cleaned up still claims to be updating");
}

@end
