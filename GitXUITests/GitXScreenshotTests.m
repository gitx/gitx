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
    if (self.app.windows.firstMatch.exists) {
        NSLog(@"[GitXScreenshotTests] Leaving the app on the history view");
        [self selectHistoryView];
    }
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

- (void)selectHistoryView {
    NSLog(@"[GitXScreenshotTests] Switching to the history view with Command-1");
    [self.app typeKey:@"1" modifierFlags:XCUIKeyModifierCommand];
    [NSThread sleepForTimeInterval:0.5];
}

- (void)selectCommitView {
    NSLog(@"[GitXScreenshotTests] Switching to the commit view with Command-2");
    [self.app typeKey:@"2" modifierFlags:XCUIKeyModifierCommand];
    [NSThread sleepForTimeInterval:0.5];
}

- (void)saveScreenshotNamed:(NSString *)name {
    XCUIScreenshot *screenshot = [[XCUIScreen mainScreen] screenshot];
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

// The title of a window whose app is not frontmost is drawn dimmed, so a
// capture taken while something else holds the activation differs from one
// taken a moment later and the comparison reports it. Ask for activation only
// when the app is not already in front, since an activation request would
// dismiss an open menu.
- (void)waitForForeground {
    if (self.app.state == XCUIApplicationStateRunningForeground)
        return;

    NSLog(@"[GitXScreenshotTests] The app is not frontmost, activating it");
    [self.app activate];

    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (self.app.state != XCUIApplicationStateRunningForeground
           && deadline.timeIntervalSinceNow > 0) {
        [NSThread sleepForTimeInterval:0.2];
    }
    XCTAssertEqual(self.app.state, XCUIApplicationStateRunningForeground,
                   @"The app should be frontmost when its window is captured");
    [NSThread sleepForTimeInterval:0.5]; // let the title bar redraw
}

- (void)saveWindowScreenshotNamed:(NSString *)name {
    [self waitForForeground];

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
    [self selectHistoryView];

    XCUIElement *window = self.app.windows.firstMatch;
    XCTAssertTrue([window.tables.firstMatch waitForExistenceWithTimeout:10],
                  @"The history view should show its commit list");
    XCTAssertFalse(window.buttons[@"Commit"].exists,
                   @"The history view should not be showing the commit view");

    [self saveWindowScreenshotNamed:@"history-view"];
}

- (void)testStagingTabScreenshot {
    XCTAssertTrue([self waitForWindow], @"Main window should appear");
    [self selectCommitView];

    XCUIElement *window = self.app.windows.firstMatch;
    XCUIElement *commitButton = window.buttons[@"Commit"];
    XCTAssertTrue([commitButton waitForExistenceWithTimeout:10],
                  @"The staging view should show its Commit button");

    // The staging view opens with the keyboard focus in the commit message
    // field, whose insertion point blinks, so whether the caret lands in the
    // picture comes down to when the capture is taken, and the comparison
    // reports a difference no pull request made. Move the focus to the diff
    // pane, which reads "No file selected" at this point and so takes it
    // without selecting or changing anything.
    NSLog(@"[GitXScreenshotTests] Moving the focus out of the commit message field");
    XCUIElement *diffPane = window.webViews.firstMatch;
    XCTAssertTrue([diffPane waitForExistenceWithTimeout:10],
                  @"The staging view should show its diff pane");
    [diffPane click];
    [NSThread sleepForTimeInterval:0.5];

    [self saveWindowScreenshotNamed:@"staging-view"];
}

// - (void)testFullScreenScreenshot {
//     // Capture the entire screen — useful for catching system-level visual regressions
//     [NSThread sleepForTimeInterval:1.0]; // let the app settle
//     [self saveScreenshotNamed:@"full-screen"];
// }

- (void)testCommitContextMenuScreenshot {
    XCTAssertTrue([self waitForWindow], @"Main window should appear");
    [self selectHistoryView];

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

- (void)testTreeViewScreenshot {
    // Reuses the same navigation as the Source/Blame/History tab tests so
    // the Tree View pane is guaranteed to have a commit and file selected.
    XCTAssertTrue([self navigateToTreeViewAndSelectFile], @"Tree View must be reachable with a file selected");
    [self saveWindowScreenshotNamed:@"tree-view"];
}

// Navigates to the Tree View, selects a commit and a file within it, so the
// Source/Blame/History scope bar (GLFileView, MGScopeBar) is visible and
// populated. Returns YES on success.
- (BOOL)navigateToTreeViewAndSelectFile {
    if (![self waitForWindow]) { return NO; }

    XCUIElement *window = self.app.windows.firstMatch;
    XCUIElement *table = window.tables.firstMatch;
    if (![table waitForExistenceWithTimeout:10]) {
        NSLog(@"[GitXScreenshotTests] Commit table not found");
        return NO;
    }

    // Let the history list fully load, then select a commit so the tree view
    // has content to render.
    [NSThread sleepForTimeInterval:1.0];
    XCUIElement *firstRow = [table.tableRows elementBoundByIndex:0];
    if (firstRow.exists) {
        [firstRow click];
        [NSThread sleepForTimeInterval:0.3];
    } else {
        NSLog(@"[GitXScreenshotTests] No commit rows found");
        return NO;
    }

    // Switch from Detailed View to Tree View (second segment of the
    // image-only segmented control). AppKit exposes an NSSegmentedControl in
    // "select one" mode to the accessibility hierarchy as a radio group of
    // radio buttons, not as XCUIElementTypeSegmentedControl. PBGitHistoryView.xib
    // also contains an unrelated search prev/next segmented control, so
    // self.app.radioGroups.firstMatch is ambiguous and can resolve to that one
    // instead. Target the Detail/Tree view switcher directly via its
    // accessibility identifier ("DetailTreeViewSwitcher", set on the
    // segmentedControl in the xib).
    XCUIElement *viewSwitcher = self.app.radioGroups[@"DetailTreeViewSwitcher"];
    if (![viewSwitcher waitForExistenceWithTimeout:15]) {
        NSLog(@"[GitXScreenshotTests] Detail/Tree view switcher not found");
        [self saveWindowScreenshotNamed:@"debug-no-view-switcher"];
        return NO;
    }
    XCUIElement *treeViewSegment = [viewSwitcher.radioButtons elementBoundByIndex:1];
    if (!treeViewSegment.exists) {
        NSLog(@"[GitXScreenshotTests] Tree View segment not found");
        return NO;
    }
    [treeViewSegment click];
    [NSThread sleepForTimeInterval:0.5];

    // Verify the click actually switched to Tree View rather than silently
    // no-opping (e.g. because the wrong control was clicked). The selected
    // radio button's AXValue is 1 (bound to selectedCommitDetailsIndex,
    // kHistoryTreeViewIndex == 1).
    if (![treeViewSegment.value isEqual:@1] && ![treeViewSegment.value isEqual:@"1"]) {
        NSLog(@"[GitXScreenshotTests] Tree View segment did not become selected after click (value=%@)", treeViewSegment.value);
        [self saveWindowScreenshotNamed:@"debug-tree-view-not-selected"];
        return NO;
    }

    // The file browser is an NSOutlineView (id "15"/PBQLOutlineView in
    // PBGitHistoryView.xib) listing the tree of the selected commit. Select
    // a file row (not just a folder) so GLFileView has text/blame/history to
    // show. Walk the rows looking for the first one that isn't a group/
    // disclosure-only row by just picking the last row, which for a typical
    // small repo tree is a file rather than the root folder.
    XCUIElement *outline = window.outlines.firstMatch;
    if (![outline waitForExistenceWithTimeout:15]) {
        NSLog(@"[GitXScreenshotTests] File tree outline not found");
        return NO;
    }
    NSUInteger rowCount = outline.outlineRows.count;
    if (rowCount == 0) {
        NSLog(@"[GitXScreenshotTests] File tree outline is empty");
        return NO;
    }
    XCUIElement *fileRow = [outline.outlineRows elementBoundByIndex:rowCount - 1];
    if (!fileRow.exists) {
        NSLog(@"[GitXScreenshotTests] Could not resolve a file row in the tree");
        return NO;
    }
    [fileRow click];
    [NSThread sleepForTimeInterval:0.5];

    return YES;
}

// Clicks the scope bar button with the given title ("Source", "Blame", or
// "History" — see GLFileView.m's MGScopeBar item setup) and saves a
// screenshot. Unlike the Detailed/Tree View segmented control, MGScopeBar
// items are titled buttons, so they can be addressed by label directly.
- (void)selectFileViewScopeBarItemNamed:(NSString *)title andSaveScreenshotNamed:(NSString *)screenshotName {
    XCUIElement *scopeBarButton = self.app.buttons[title];
    XCTAssertTrue([scopeBarButton waitForExistenceWithTimeout:15],
        @"Scope bar button '%@' must appear", title);
    [scopeBarButton click];
    [NSThread sleepForTimeInterval:0.5];
    [self saveWindowScreenshotNamed:screenshotName];
}

- (void)testTreeViewSourceTabScreenshot {
    XCTAssertTrue([self navigateToTreeViewAndSelectFile], @"Tree View must be reachable with a file selected");
    [self selectFileViewScopeBarItemNamed:@"Source" andSaveScreenshotNamed:@"tree-view-source"];
}

- (void)testTreeViewBlameTabScreenshot {
    XCTAssertTrue([self navigateToTreeViewAndSelectFile], @"Tree View must be reachable with a file selected");
    [self selectFileViewScopeBarItemNamed:@"Blame" andSaveScreenshotNamed:@"tree-view-blame"];
}

- (void)testTreeViewHistoryTabScreenshot {
    XCTAssertTrue([self navigateToTreeViewAndSelectFile], @"Tree View must be reachable with a file selected");
    [self selectFileViewScopeBarItemNamed:@"History" andSaveScreenshotNamed:@"tree-view-history"];
}

@end

