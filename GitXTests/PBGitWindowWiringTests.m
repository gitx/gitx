//
//  PBGitWindowWiringTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitWindowController.h"
#import "PBGitRepository.h"
#import "PBGitSidebarController.h"
#import "PBGitHistoryController.h"
#import "PBGitHistoryList.h"
#import "PBGitCommit.h"
#import "PBGitRef.h"
#import "PBSourceViewItem.h"

// -selectedRef is private to the window controller, so the test names it the
// same way the other suites name the seams they drive.
@interface PBGitWindowController (PBSelectedRefTests)
- (PBGitRef *)selectedRefForResponder:(id)responder;
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
							 @"PATH" : @"/usr/bin:/bin",
							 @"GIT_CONFIG_GLOBAL" : @"/dev/null",
							 @"GIT_CONFIG_SYSTEM" : @"/dev/null"};

		NSError *error = nil;
		if (![task launchAndReturnError:&error]) {
			XCTFail(@"git %@ did not start: %@", arguments.firstObject, error);
			break;
		}

		[task waitUntilExit];
		XCTAssertEqual(task.terminationStatus, 0, @"git %@ failed, so the repository is not the one these tests describe", arguments.firstObject);
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

	[self waitForTheRevisionListToSettle];
}

// Deleting the repository under a walk that is still running makes it fail,
// and -addCommitsFromEnumerator: asserts on that.
- (void)waitForTheRevisionListToSettle
{
	PBGitHistoryList *revisionList = self.windowController.repository.revisionList;
	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:30];

	while (revisionList.isUpdating && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	XCTAssertFalse(revisionList.isUpdating, @"the revision list is still walking the repository");
}

- (void)tearDown
{
	[self.windowController.repository.revisionList cleanup];
	[self waitForTheRevisionListToSettle];

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

// Which list is being asked is read off the first responder, and a test cannot
// hold the keyboard focus: anything that takes it during the run hands it back
// to the window. So the list is handed over rather than focused.
- (NSResponder *)sidebarSelecting:(NSString *)refName
{
	NSOutlineView *sourceView = self.windowController.sidebarViewController.sourceView;

	NSInteger row = [self sidebarRowForRefNamed:refName];
	XCTAssertNotEqual(row, -1, @"%@ has to be on screen before it can be selected", refName);
	[sourceView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

	return sourceView;
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
- (NSResponder *)historyListSelecting:(NSString *)refName
{
	PBGitHistoryController *history = self.windowController.historyViewController;
	PBGitCommit *commit = [self commitForRefNamed:refName];

	[history.commitController unbind:NSContentArrayBinding];
	[history.commitController setContent:@[ commit ]];
	[history.commitController setSelectedObjects:@[ commit ]];

	NSString *immediately = [self selectionStateOf:history];

	NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:5];
	while (!history.singleCommitSelected && [limit timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];

	XCTAssertTrue(history.singleCommitSelected, @"the history list never took the selection.\n  straight after asking: %@\n  after waiting:         %@\n  wiring:                %@\n  host state:            %@",
				  immediately, [self selectionStateOf:history], [self wiringStateOf:history], [self hostState]);

	return (NSResponder *)history.commitList;
}

// An array controller answers an empty index set when nothing is selected, so
// a selectionIndexes of (null) means the outlet itself never got connected. The
// nib builds the controller and the list alike, and both are reported here
// rather than inferred from one another.
- (NSString *)wiringStateOf:(PBGitHistoryController *)history
{
	// Read each one once into a local: commitList is a weak outlet, and asking
	// for it twice in one format call can answer differently.
	NSArrayController *controller = history.commitController;
	NSTableView *list = (NSTableView *)history.commitList;
	NSView *view = history.view;

	return [NSString stringWithFormat:@"history: %@, commitController: %@, commitList: %@, view: %@, window: %@, columns: %lu, sortDescriptors: %lu",
									  history ? @"set" : @"nil",
									  controller ? @"set" : @"nil",
									  list ? @"set" : @"nil",
									  view ? @"set" : @"nil",
									  view.window ? @"set" : @"nil",
									  (unsigned long)list.tableColumns.count,
									  (unsigned long)controller.sortDescriptors.count];
}
// A GitX that ran before these tests leaves its autosaved table and window
// state in the same defaults domain the test host reads, so what is already
// there is part of the state under test.
- (NSString *)hostState
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	return [NSString stringWithFormat:@"saved columns: %@, saved sort: %@, saved window: %@, PBCommitDateFormat: %@",
									  [defaults objectForKey:@"NSTableView Columns v3 CommitView"] ? @"yes" : @"no",
									  [defaults objectForKey:@"NSTableView Sort Ordering v2 CommitView"] ? @"yes" : @"no",
									  [defaults objectForKey:@"NSWindow Frame GitX"] ? @"yes" : @"no",
									  [defaults objectForKey:@"PBCommitDateFormat"]];
}

// -singleCommitSelected reads -selectedCommits, which only -updateKeys writes,
// and that runs from the observer on the array controller's selection. So a
// failure can mean the controller refused the selection or that the hop has not
// happened, and the two are told apart by what the controller itself holds.
- (NSString *)selectionStateOf:(PBGitHistoryController *)history
{
	NSArrayController *controller = history.commitController;
	PBGitCommit *wanted = [[controller content] firstObject];

	return [NSString stringWithFormat:@"content: %lu, arranged: %lu, wanted commit is arranged: %@, selectionIndexes: %@, selectedObjects: %lu, selectedCommits: %lu",
									  (unsigned long)[[controller content] count],
									  (unsigned long)[[controller arrangedObjects] count],
									  [[controller arrangedObjects] containsObject:wanted] ? @"yes" : @"no",
									  [controller selectionIndexes],
									  (unsigned long)[[controller selectedObjects] count],
									  (unsigned long)history.selectedCommits.count];
}

// Every ref action asks -selectedRef which ref it should work on. With the
// sidebar unreachable that question could only ever be answered by the history
// list, so a branch picked in the sidebar named nothing at all.
- (void)testTheFocusedSidebarNamesTheBranchItHasSelected
{
	XCTAssertNil([self.windowController selectedRefForResponder:nil], @"with neither list focused nothing is named");

	NSResponder *sidebar = [self sidebarSelecting:@"refs/heads/branch_two"];

	XCTAssertEqualObjects([self.windowController selectedRefForResponder:sidebar].ref, @"refs/heads/branch_two");
}

// A row directly under REMOTES stands for the whole remote rather than for any
// one of its branches, and fetch and pull are offered on that.
- (void)testTheFocusedSidebarNamesAWholeRemoteByItsOwnRef
{
	NSResponder *sidebar = [self sidebarSelecting:@"refs/remotes/origin"];

	XCTAssertEqualObjects([self.windowController selectedRefForResponder:sidebar].ref, @"refs/remotes/origin");
}

// The history list keeps answering as it always has: the branch label on the
// selected commit, when there is exactly one.
- (void)testTheFocusedHistoryListNamesTheBranchOnItsSelectedCommit
{
	NSResponder *historyList = [self historyListSelecting:@"refs/heads/branch_one"];

	XCTAssertEqualObjects([self.windowController selectedRefForResponder:historyList].ref, @"refs/heads/branch_one");
}

// Two branches sit on the root commit, so the history list cannot say which one
// an action was meant for and names neither.
- (void)testACommitCarryingTwoBranchesNamesNeither
{
	NSResponder *historyList = [self historyListSelecting:@"refs/heads/branch_two"];

	XCTAssertNil([self.windowController selectedRefForResponder:historyList]);
}

@end
