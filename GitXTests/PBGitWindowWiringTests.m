//
//  PBGitWindowWiringTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitWindowController.h"
#import "PBGitRepository.h"
#import "PBGitSidebarController.h"
#import "PBGitDefaults.h"
#import "PBGitHistoryController.h"
#import "PBGitHistoryList.h"
#import "PBGitRevList.h"
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
@property (nonatomic, strong) id settingToPutBack;
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

	// The sidebar opens whichever view this preference names, and the window
	// loads a nib only for the controller it shows, so a GitX left on the stage
	// view would leave the history list and its array controller nil here. The
	// tests run in the application, so put back what was there afterwards.
	self.settingToPutBack = [[NSUserDefaults standardUserDefaults] objectForKey:@"PBShowStageView"];
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PBShowStageView"];
	XCTAssertFalse([PBGitDefaults showStageView], @"the preference this suite turns off is read under some other name now, so it is no longer being turned off");

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

	XCTAssertFalse(revisionList.isUpdating, @"the revision list is still walking the repository, %@", [self outstandingWorkOf:revisionList]);
}

// -finishedGraphing clears isUpdating only once the walk has stopped parsing and
// the graph queue has drained, so a wait that expires has to say which of the
// two is still outstanding; otherwise the next failure in CI says no more than
// this one did. Both of them live in ivars, which KVC reaches by name.
- (NSString *)outstandingWorkOf:(PBGitHistoryList *)revisionList
{
	PBGitRevList *walk = [revisionList valueForKey:@"currentRevList"];
	NSOperationQueue *graphQueue = [revisionList valueForKey:@"graphQueue"];

	return [NSString stringWithFormat:@"walk parsing: %@, graph operations: %lu",
									  walk ? (walk.isParsing ? @"yes" : @"no") : @"no walk",
									  (unsigned long)graphQueue.operationCount];
}

- (void)tearDown
{
	[self.windowController.repository.revisionList cleanup];
	[self waitForTheRevisionListToSettle];

	[self.windowController close];
	self.windowController = nil;
	[[NSFileManager defaultManager] removeItemAtURL:self.repositoryURL error:NULL];

	if (self.settingToPutBack)
		[[NSUserDefaults standardUserDefaults] setObject:self.settingToPutBack forKey:@"PBShowStageView"];
	else
		[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PBShowStageView"];

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

	XCTAssertTrue(history.singleCommitSelected);

	return (NSResponder *)history.commitList;
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
