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

    // Find a git repo to open: prefer a fixture bundled with the test target,
    // fall back to the source repo alongside the built product.
    NSString *repoPath = nil;

    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSURL *bundledRepo = [bundle URLForResource:@"testrepo" withExtension:nil];
    if (bundledRepo && [[NSFileManager defaultManager] fileExistsAtPath:bundledRepo.path]) {
        repoPath = bundledRepo.path;
    }

    if (!repoPath) {
        // Use the gitx source repo itself — always present on any checkout
        NSURL *bundleURL = bundle.bundleURL;
        // Walk up from <DerivedData>/…/Build/Products/<config>/<TestBundle>.xctest
        NSURL *candidate = bundleURL;
        for (int i = 0; i < 8; i++) {
            candidate = candidate.URLByDeletingLastPathComponent;
            NSURL *gitDir = [candidate URLByAppendingPathComponent:@".git"];
            if ([[NSFileManager defaultManager] fileExistsAtPath:gitDir.path]) {
                repoPath = candidate.path;
                break;
            }
        }
    }

    // Suppress the "Open Recent" dialog that would otherwise appear when no
    // document is provided, by disabling the untitled-file prompt.
    self.app.launchArguments = @[@"-AppleNoUntitledDocuments", @"YES"];

    [self.app launch];

    if (repoPath) {
        // GITX_UITEST_REPO is read in applicationDidFinishLaunching: to open
        // the repo directly, giving XCUITests a reliable document window.
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
    // As a last resort, activate the app and try once more
    [self.app activate];
    return [self.app.windows.firstMatch waitForExistenceWithTimeout:10];
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
    [self saveWindowScreenshotNamed:@"main-window"];
}

- (void)testHistoryTabScreenshot {
    if (![self waitForWindow]) { return; }
    [self saveWindowScreenshotNamed:@"history-view"];
}

- (void)testStagingTabScreenshot {
    if (![self waitForWindow]) { return; }

    // Click the Stage tab / toolbar button if present
    XCUIElement *stageButton = self.app.toolbars.buttons[@"Stage"];
    if (!stageButton.exists) {
        // Try as a tab or segmented control
        stageButton = [self.app.windows.firstMatch.buttons elementMatchingType:XCUIElementTypeButton
                                                                    identifier:@"Stage"];
    }
    if (stageButton.exists) {
        [stageButton click];
        [NSThread sleepForTimeInterval:0.5];
    }

    [self saveWindowScreenshotNamed:@"staging-view"];
}

- (void)testFullScreenScreenshot {
    // Capture the entire screen — useful for catching system-level visual regressions
    [NSThread sleepForTimeInterval:1.0]; // let the app settle
    [self saveScreenshotNamed:@"full-screen"];
}

@end

