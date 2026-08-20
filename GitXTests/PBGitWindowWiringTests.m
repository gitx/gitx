//
//  PBGitWindowWiringTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitWindowController.h"
#import "PBGitRepository.h"
#import "PBGitSidebarController.h"
#import "PBGitHistoryController.h"
#import "PBGitCommit.h"
#import "PBGitRef.h"
#import "PBSourceViewItem.h"

// -selectedRef is private to the window controller, so the test names it the
// same way the other suites name the seams they drive.
@interface PBGitWindowController (PBSelectedRefTests)
- (PBGitRef *)selectedRef;
@end

// The window controller takes its repository from its document. A test has no
// document, so it supplies the repository directly and lets everything else
// run as it does in the application.
@interface PBStubWindowController : PBGitWindowController
@property (nonatomic, strong) PBGitRepository *stubRepository;
@end

@implementation PBStubWindowController

- (PBGitRepository *)repository
{
	return self.stubRepository;
}

@end

@interface PBGitWindowWiringTests : XCTestCase
@property (nonatomic, strong) PBStubWindowController *windowController;
@property (nonatomic, strong) NSURL *repositoryURL;
@end

@implementation PBGitWindowWiringTests

- (NSURL *)makeRepository
{
	NSURL *URL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:[NSUUID UUID].UUIDString];
	[[NSFileManager defaultManager] createDirectoryAtURL:URL withIntermediateDirectories:YES attributes:nil error:NULL];

	// branch_one ends up one commit ahead, so its tip carries a single branch
	// label while the root commit carries two, plus a remote that gives the
	// sidebar a REMOTES row to select.
	NSArray *script = @[
		@[ @"init", @"-q" ],
		@[ @"symbolic-ref", @"HEAD", @"refs/heads/branch_one" ],
		@[ @"commit", @"-q", @"--allow-empty", @"-m", @"root" ],
		@[ @"branch", @"branch_two" ],
		@[ @"branch", @"branch_three" ],
		@[ @"update-ref", @"refs/remotes/origin/branch_one", @"HEAD" ],
		@[ @"commit", @"-q", @"--allow-empty", @"-m", @"tip" ],
	];

	for (NSArray *arguments in script) {
		NSTask *task = [[NSTask alloc] init];
		task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/git"];
		task.currentDirectoryURL = URL;
		task.arguments = arguments;
		task.environment = @{@"GIT_AUTHOR_NAME" : @"t", @"GIT_AUTHOR_EMAIL" : @"t@t",
							 @"GIT_COMMITTER_NAME" : @"t", @"GIT_COMMITTER_EMAIL" : @"t@t",
							 @"PATH" : @"/usr/bin:/bin"};
		[task launchAndReturnError:NULL];
		[task waitUntilExit];
	}

	return URL;
}

- (void)setUp
{
	[super setUp];

	self.repositoryURL = [self makeRepository];

	NSError *error = nil;
	PBGitRepository *repository = [[PBGitRepository alloc] initWithURL:self.repositoryURL error:&error];
	XCTAssertNotNil(repository, @"%@", error);

	self.windowController = [[PBStubWindowController alloc] init];
	self.windowController.stubRepository = repository;

	// Asking for the window loads the nib, which is what runs -windowDidLoad
	// and builds the three view controllers
	XCTAssertNotNil(self.windowController.window);
}

- (void)tearDown
{
	[self.windowController close];
	self.windowController = nil;
	[[NSFileManager defaultManager] removeItemAtURL:self.repositoryURL error:NULL];

	[super tearDown];
}

// -sidebarViewController returned nil for years because the window controller
// assigned the sidebar to an ivar the property does not read. Nothing crashed:
// messaging nil is silent, so only code that needed a real object noticed.
- (void)testTheWindowHandsOutTheControllersItBuilt
{
	XCTAssertNotNil(self.windowController.sidebarViewController,
					@"the sidebar has to be reachable, or every caller silently talks to nil");
	XCTAssertNotNil(self.windowController.historyViewController);
	XCTAssertNotNil(self.windowController.commitViewController);
}

// The property has to hand back the same sidebar that was put on screen, not
// some second instance.
- (void)testTheSidebarHandedOutIsTheOneOnScreen
{
	PBGitSidebarController *sidebar = self.windowController.sidebarViewController;

	XCTAssertNotNil(sidebar.view.superview, @"the sidebar reached through the property is the installed one");
}

- (NSInteger)sidebarRowForRefNamed:(NSString *)refName
{
	NSOutlineView *sourceView = self.windowController.sidebarViewController.sourceView;
	for (NSInteger row = 0; row < sourceView.numberOfRows; row++) {
		PBSourceViewItem *item = [sourceView itemAtRow:row];
		if ([item.ref.ref isEqualToString:refName])
			return row;
	}
	return -1;
}

- (void)focusSidebarOnRefNamed:(NSString *)refName
{
	NSOutlineView *sourceView = self.windowController.sidebarViewController.sourceView;

	NSInteger row = [self sidebarRowForRefNamed:refName];
	XCTAssertNotEqual(row, -1, @"%@ has to be on screen before it can be selected", refName);
	[sourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	XCTAssertTrue([self.windowController.window makeFirstResponder:sourceView]);
}

// The commit is read straight out of the repository because the revision list
// loads asynchronously. Its labels are the real ones: -refs comes from the
// repository's ref table, which is what the history list draws.
- (PBGitCommit *)commitForRefNamed:(NSString *)refName
{
	PBGitRepository *repository = self.windowController.repository;

	GTOID *OID = [repository OIDForRef:[PBGitRef refFromString:refName]];
	XCTAssertNotNil(OID, @"%@ has to exist in the fixture", refName);

	GTCommit *gtCommit = [repository.gtRepo lookUpObjectByOID:OID objectType:GTObjectTypeCommit error:NULL];
	return [[PBGitCommit alloc] initWithRepository:repository andCommit:gtCommit];
}

// The array controller takes its content from the revision list, which would
// refill it from disk on its own schedule. Detaching that binding first is what
// lets the test decide which commit is on screen.
- (void)focusHistoryListOnRefNamed:(NSString *)refName
{
	PBGitHistoryController *history = self.windowController.historyViewController;
	PBGitCommit *commit = [self commitForRefNamed:refName];

	XCTAssertTrue([self.windowController.window makeFirstResponder:(NSResponder *)history.commitList]);

	[history.commitController unbind:NSContentArrayBinding];
	[history.commitController setContent:@[ commit ]];
	[history.commitController setSelectedObjects:@[ commit ]];

	XCTAssertTrue(history.singleCommitSelected);
}

// Every ref action asks -selectedRef which ref it should work on. With the
// sidebar unreachable that question could only ever be answered by the history
// list, so a branch picked in the sidebar named nothing at all.
- (void)testTheFocusedSidebarNamesTheBranchItHasSelected
{
	XCTAssertNil(self.windowController.selectedRef, @"with neither list focused nothing is named");

	[self focusSidebarOnRefNamed:@"refs/heads/branch_two"];

	XCTAssertEqualObjects(self.windowController.selectedRef.ref, @"refs/heads/branch_two");
}

// A row directly under REMOTES stands for the whole remote rather than for any
// one of its branches, and fetch and pull are offered on that.
- (void)testTheFocusedSidebarNamesAWholeRemoteByItsOwnRef
{
	[self focusSidebarOnRefNamed:@"refs/remotes/origin"];

	XCTAssertEqualObjects(self.windowController.selectedRef.ref, @"refs/remotes/origin");
}

// The history list keeps answering as it always has: the branch label on the
// selected commit, when there is exactly one.
- (void)testTheFocusedHistoryListNamesTheBranchOnItsSelectedCommit
{
	[self focusHistoryListOnRefNamed:@"refs/heads/branch_one"];

	XCTAssertEqualObjects(self.windowController.selectedRef.ref, @"refs/heads/branch_one");
}

// Two branches sit on the root commit, so the history list cannot say which one
// an action was meant for and names neither.
- (void)testACommitCarryingTwoBranchesNamesNeither
{
	[self focusHistoryListOnRefNamed:@"refs/heads/branch_two"];

	XCTAssertNil(self.windowController.selectedRef);
}

@end
