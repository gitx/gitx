//
//  PBGitWindowWiringTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitWindowController.h"
#import "PBGitRepository.h"
#import "PBGitSidebarController.h"

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

	for (NSArray *arguments in @[ @[ @"init", @"-q" ], @[ @"commit", @"-q", @"--allow-empty", @"-m", @"root" ] ]) {
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

@end
