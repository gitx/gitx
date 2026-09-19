//
//  GitXScreenshotTests.m
//  GitXUITests
//
//  Screenshot tests using XCUIApplication.
//  Screenshots are saved as test attachments and uploaded as CI artifacts.
//  No external dependencies required.
//

#import <XCTest/XCTest.h>

@interface GitXScreenshotTests : XCTestCase
@property (nonatomic, strong) XCUIApplication *app;
@end

@implementation GitXScreenshotTests

- (void)setUp {
    [super setUp];
    self.continueAfterFailure = NO;
    self.app = [[XCUIApplication alloc] init];

    // GITX_UITEST_REPO is set by the scheme to $(GITX_SCREENSHOT_REPO).
    // Locally this expands to $(SRCROOT). On CI, xcodebuild overrides
    // GITX_SCREENSHOT_REPO=/tmp/gitx-screenshot-repo (the fixed commit checkout).
    NSDictionary *env = [[NSProcessInfo processInfo] environment];
    NSString *repoPath = env[@"GITX_UITEST_REPO"];

    if (!repoPath) {
        // Fallback: a fixture repo bundled with the test target
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSURL *bundledRepo = [bundle URLForResource:@"testrepo" withExtension:nil];
        if (bundledRepo && [[NSFileManager defaultManager] fileExistsAtPath:bundledRepo.path]) {
            repoPath = bundledRepo.path;
        }
    }

    NSLog(@"[GitXScreenshotTests] repoPath = %@", repoPath ?: @"(none)");

    if (repoPath) {
        // Passed to the app via applicationDidFinishLaunching: which opens
        // the repo directly, giving the test a reliable document window.
        self.app.launchEnvironment = @{@"GITX_UITEST_REPO": repoPath};
    }

    [self.app launch];
}

- (void)tearDown {
    [self.app terminate];
    [super tearDown];
}

// MARK: - Helpers

- (BOOL)waitForWindow {
    XCUIElement *window = self.app.windows.firstMatch;
    if ([window waitForExistenceWithTimeout:20]) {
        return YES;
    }
    // Activate the app and give it one more chance — it may have launched
    // but not yet brought its window to the front.
    [self.app activate];
    return [self.app.windows.firstMatch waitForExistenceWithTimeout:10];
}

- (BOOL)selectViewMenuItem:(NSString *)title {
    XCUIElement *viewMenu = self.app.menuBars.menuBarItems[@"View"];
    if (![viewMenu waitForExistenceWithTimeout:10]) {
        NSLog(@"[GitXScreenshotTests] The View menu never appeared");
        return NO;
    }
    [viewMenu click];

    XCUIElement *item = viewMenu.menus.menuItems[title];
    if (![item waitForExistenceWithTimeout:5]) {
        NSLog(@"[GitXScreenshotTests] View > %@ was not offered", title);
        [self.app typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
        return NO;
    }

    NSLog(@"[GitXScreenshotTests] Switching to View > %@", title);
    [item click];
    [NSThread sleepForTimeInterval:0.5];
    return YES;
}

- (void)saveScreenshotNamed:(NSString *)name {
    XCUIScreenshot *screenshot = [[XCUIScreen mainScreen] screenshot];
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (void)saveWindowScreenshotNamed:(NSString *)name {
    XCUIElement *window = self.app.windows.firstMatch;
    if (!window.exists) {
        [self saveScreenshotNamed:name]; // fall back to full screen
        return;
    }
    XCUIScreenshot *screenshot = [window screenshot];
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

// MARK: - Tests

- (void)testMainWindowExists {
    XCTAssertTrue([self waitForWindow],
                  @"Main window should appear within 30 seconds");
}

- (void)testHistoryTabScreenshot {
    XCTAssertTrue([self waitForWindow], @"Main window should appear");
    XCTAssertTrue([self selectViewMenuItem:@"History"],
                  @"View > History should be reachable");

    XCUIElement *table = self.app.windows.firstMatch.tables.firstMatch;
    XCTAssertTrue([table waitForExistenceWithTimeout:10],
                  @"The history view should show its commit list");

    [self saveWindowScreenshotNamed:@"history-view"];
}

- (void)testStagingTabScreenshot {
    XCTAssertTrue([self waitForWindow], @"Main window should appear");
    XCTAssertTrue([self selectViewMenuItem:@"Commit"],
                  @"View > Commit should be reachable");

    XCUIElement *commitButton = self.app.windows.firstMatch.buttons[@"Commit"];
    XCTAssertTrue([commitButton waitForExistenceWithTimeout:10],
                  @"The staging view should show its Commit button");

    [self saveWindowScreenshotNamed:@"staging-view"];
}

// - (void)testFullScreenScreenshot {
//     // Capture the entire screen — useful for catching system-level visual regressions
//     [NSThread sleepForTimeInterval:1.0]; // let the app settle
//     [self saveScreenshotNamed:@"full-screen"];
// }

- (void)testCommitContextMenuScreenshot {
    XCTAssertTrue([self waitForWindow], @"Main window should appear");
    XCTAssertTrue([self selectViewMenuItem:@"History"],
                  @"View > History should be reachable");

    // The commit list is a table — find the first (most recent) commit row
    XCUIElement *window = self.app.windows.firstMatch;
    XCUIElement *table = window.tables.firstMatch;
    if (![table waitForExistenceWithTimeout:10]) {
        NSLog(@"[GitXScreenshotTests] Commit table not found, skipping context menu screenshot");
        return;
    }

    // Let the history list fully load
    [NSThread sleepForTimeInterval:1.0];

    XCUIElement *firstRow = [table.tableRows elementBoundByIndex:0];
    if (!firstRow.exists) {
        NSLog(@"[GitXScreenshotTests] No commit rows found, skipping context menu screenshot");
        return;
    }

    // Right-click to open the context menu
    [firstRow rightClick];

    // Wait for the menu to appear
    XCUIElement *menu = self.app.menus.firstMatch;
    if (![menu waitForExistenceWithTimeout:5]) {
        NSLog(@"[GitXScreenshotTests] Context menu did not appear");
        return;
    }

    [NSThread sleepForTimeInterval:0.3]; // let the menu fully render
    [self saveWindowScreenshotNamed:@"commit-context-menu"];

    // Dismiss the menu
    [window typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
}

@end

