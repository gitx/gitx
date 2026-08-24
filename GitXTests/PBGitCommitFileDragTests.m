//
//  PBGitCommitFileDragTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitCommitController.h"
#import "PBGitRepository.h"
#import "PBChangedFile.h"

// The drag payload the two tables exchange between themselves, named in
// PBGitCommitController.m and not exported from it.
static NSString *const PBFileChangesTableViewType = @"net.phere.GitX.changed-file";

// -[PBGitRepository workingDirectoryURL] asks libgit2 for the checkout, so
// the test hands the controller a repository that answers on its own.
@interface PBFixedDirectoryRepository : PBGitRepository
@end

@implementation PBFixedDirectoryRepository
- (NSURL *)workingDirectoryURL
{
	return [NSURL fileURLWithPath:@"/gitx-drag-tests" isDirectory:YES];
}
@end

// The table asks the commit controller for one pasteboard writer per dragged
// row through a data source method the class does not publish, so the test
// names it the way the other suites here do.
@interface PBGitCommitController (PBFileDragTests)
- (id<NSPasteboardWriting>)tableView:(NSTableView *)tv pasteboardWriterForRow:(NSInteger)row;
@end

@interface PBGitCommitFileDragTests : XCTestCase
@property (nonatomic, strong) PBGitCommitController *controller;
@property (nonatomic, strong) PBGitRepository *repository;
@property (nonatomic, strong) NSTableView *unstagedTable;
@property (nonatomic, strong) NSPasteboard *pasteboard;
@end

@implementation PBGitCommitFileDragTests

- (void)setUp
{
	[super setUp];

	// The controller holds its table and its repository weakly, so the test
	// owns them instead.
	self.unstagedTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
	self.unstagedTable.tag = 0;

	self.repository = [[PBFixedDirectoryRepository alloc] init];

	NSArrayController *unstagedFiles = [[NSArrayController alloc] initWithContent:@[
		[[PBChangedFile alloc] initWithPath:@"first.txt"],
		[[PBChangedFile alloc] initWithPath:@"second.txt"]
	]];

	self.controller = [[PBGitCommitController alloc] init];
	[self.controller setValue:self.repository forKey:@"repository"];
	[self.controller setValue:self.unstagedTable forKey:@"unstagedTable"];
	[self.controller setValue:unstagedFiles forKey:@"unstagedFilesController"];

	self.pasteboard = [NSPasteboard pasteboardWithUniqueName];
}

- (void)tearDown
{
	[self.pasteboard releaseGlobally];
	self.pasteboard = nil;
	self.controller = nil;
	self.repository = nil;
	self.unstagedTable = nil;

	[super tearDown];
}

// A drag writes one item per row, which is what the table does with the
// writers it is handed.
- (NSUInteger)dragRows:(NSIndexSet *)rowIndexes
{
	NSMutableArray *items = [NSMutableArray array];
	[rowIndexes enumerateIndexesUsingBlock:^(NSUInteger row, BOOL *stop) {
		id<NSPasteboardWriting> item = [self.controller tableView:self.unstagedTable pasteboardWriterForRow:row];
		if (item)
			[items addObject:item];
	}];

	[self.pasteboard clearContents];
	[self.pasteboard writeObjects:items];

	return items.count;
}

- (NSArray<NSString *> *)pathsOnThePasteboard
{
	NSDictionary *options = @{NSPasteboardURLReadingFileURLsOnlyKey : @YES};
	NSArray<NSURL *> *fileURLs = [self.pasteboard readObjectsForClasses:@[ [NSURL class] ] options:options];

	NSMutableArray<NSString *> *paths = [NSMutableArray arrayWithCapacity:fileURLs.count];
	for (NSURL *fileURL in fileURLs)
		[paths addObject:fileURL.path];

	return paths;
}

- (void)testOffersEveryDraggedFileToTheReceivingApplication
{
	XCTAssertEqual([self dragRows:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]], 2u);

	XCTAssertEqualObjects([self pathsOnThePasteboard],
						  (@[ @"/gitx-drag-tests/first.txt", @"/gitx-drag-tests/second.txt" ]));
}

// A drag of several rows has to put each on its own item. Written as one item
// carrying them all, the table never starts the drag at all.
- (void)testWritesOneItemForEachDraggedRow
{
	[self dragRows:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]];

	XCTAssertEqual(self.pasteboard.pasteboardItems.count, 2u);
}

- (void)testKeepsTheRowsReadableForADragBetweenTheTables
{
	[self dragRows:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 2)]];

	NSMutableArray<NSString *> *rows = [NSMutableArray array];
	for (NSPasteboardItem *item in self.pasteboard.pasteboardItems) {
		NSString *row = [item stringForType:PBFileChangesTableViewType];
		if (row)
			[rows addObject:row];
	}

	XCTAssertEqualObjects(rows, (@[ @"0", @"1" ]));
}

@end
