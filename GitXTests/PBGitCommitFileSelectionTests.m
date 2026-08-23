//
//  PBGitCommitFileSelectionTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitCommitController.h"
#import "PBChangedFile.h"

// The file actions ask the commit controller which of its two tables a menu
// item came from before reading a selection, and that seam is private to the
// class, so the test names it the way the other suites here do.
@interface PBGitCommitController (PBFileSelectionTests)
- (NSArray<PBChangedFile *> *)selectedFilesForSender:(id)sender;
@end

@interface PBGitCommitFileSelectionTests : XCTestCase
@property (nonatomic, strong) PBGitCommitController *controller;
@property (nonatomic, strong) NSTableView *unstagedTable;
@property (nonatomic, strong) NSTableView *stagedTable;
@property (nonatomic, strong) PBChangedFile *unstagedFile;
@property (nonatomic, strong) PBChangedFile *stagedFile;
@end

@implementation PBGitCommitFileSelectionTests

- (void)setUp
{
	[super setUp];

	// The controller holds its tables weakly, so the test owns them instead.
	self.unstagedTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
	self.unstagedTable.tag = 0;
	self.unstagedTable.menu = [[NSMenu alloc] initWithTitle:@"Unstaged"];

	self.stagedTable = [[NSTableView alloc] initWithFrame:NSZeroRect];
	self.stagedTable.tag = 1;
	self.stagedTable.menu = [[NSMenu alloc] initWithTitle:@"Staged"];

	self.unstagedFile = [[PBChangedFile alloc] initWithPath:@"unstaged.txt"];
	self.stagedFile = [[PBChangedFile alloc] initWithPath:@"staged.txt"];

	NSArrayController *unstagedFiles = [[NSArrayController alloc] initWithContent:@[ self.unstagedFile ]];
	[unstagedFiles setSelectedObjects:@[ self.unstagedFile ]];

	NSArrayController *stagedFiles = [[NSArrayController alloc] initWithContent:@[ self.stagedFile ]];
	[stagedFiles setSelectedObjects:@[ self.stagedFile ]];

	self.controller = [[PBGitCommitController alloc] init];
	[self.controller setValue:self.unstagedTable forKey:@"unstagedTable"];
	[self.controller setValue:self.stagedTable forKey:@"stagedTable"];
	[self.controller setValue:unstagedFiles forKey:@"unstagedFilesController"];
	[self.controller setValue:stagedFiles forKey:@"stagedFilesController"];
}

- (void)tearDown
{
	self.controller = nil;
	self.stagedTable = nil;
	self.unstagedTable = nil;
	self.stagedFile = nil;
	self.unstagedFile = nil;

	[super tearDown];
}

- (NSMenuItem *)itemInMenu:(NSMenu *)menu
{
	NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Open"
												  action:@selector(openFiles:)
										   keyEquivalent:@""];
	[menu addItem:item];
	return item;
}

- (void)testTakesTheStagedSelectionForTheStagedTablesMenu
{
	NSArray<PBChangedFile *> *files = [self.controller selectedFilesForSender:[self itemInMenu:self.stagedTable.menu]];

	XCTAssertEqualObjects(files, @[ self.stagedFile ]);
}

- (void)testTakesTheUnstagedSelectionForTheUnstagedTablesMenu
{
	NSArray<PBChangedFile *> *files = [self.controller selectedFilesForSender:[self itemInMenu:self.unstagedTable.menu]];

	XCTAssertEqualObjects(files, @[ self.unstagedFile ]);
}

@end
