//
//  PBFileChangesTableViewDragTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBFileChangesTableView.h"

@interface PBFileChangesTableViewDragTests : XCTestCase
@property (nonatomic, strong) PBFileChangesTableView *tableView;
@end

@implementation PBFileChangesTableViewDragTests

- (void)setUp
{
	[super setUp];

	self.tableView = [[PBFileChangesTableView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
}

- (void)tearDown
{
	self.tableView = nil;
	[super tearDown];
}

// The table view answers this before a drag begins and never reads the
// session, so the tests hand it one it can safely ignore.
- (NSDragOperation)operationForContext:(NSDraggingContext)context
{
	NSDraggingSession *session = nil;
	return [self.tableView draggingSession:session sourceOperationMaskForDraggingContext:context];
}

- (void)testOffersOnlyACopyOnceTheDragLeavesGitX
{
	XCTAssertEqual([self operationForContext:NSDraggingContextOutsideApplication], NSDragOperationCopy,
				   @"dropping a changed file on another application must leave the working copy alone");
}

- (void)testStillOffersEveryOperationWithinGitX
{
	XCTAssertEqual([self operationForContext:NSDraggingContextWithinApplication], NSDragOperationEvery,
				   @"staging and unstaging by drag rely on a move being offered inside GitX");
}

@end
