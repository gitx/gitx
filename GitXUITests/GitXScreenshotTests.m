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

// MARK: - Settings / Preferences

- (void)openPreferencesWindow {
    // Use the menu bar — more reliable than ⌘, in UI tests because the
    // main window is guaranteed to have focus after waitForWindow.
    XCUIElement *appMenu = self.app.menuBars.firstMatch;
    // "GitX" application menu
    XCUIElement *gitxMenu = appMenu.menuBarItems[@"GitX"];
    if ([gitxMenu waitForExistenceWithTimeout:10]) {
        [gitxMenu click];
        // Clicking the menu bar item only opens the submenu asynchronously;
        // its items are not in the accessibility tree immediately, so a bare
        // `.exists` check races the menu's open animation and can miss items
        // that are about to appear. Wait for them instead.
        XCUIElement *prefsItem = self.app.menuItems[@"Preferences…"];
        if (![prefsItem waitForExistenceWithTimeout:5]) {
            prefsItem = self.app.menuItems[@"Settings…"];
        }
        if ([prefsItem waitForExistenceWithTimeout:5]) {
            [prefsItem click];
            return;
        }
        NSLog(@"[GitXScreenshotTests] Preferences/Settings menu item not found");
        // Dismiss the menu before falling back
        [appMenu typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
    } else {
        NSLog(@"[GitXScreenshotTests] GitX application menu not found");
    }
    // Fallback: keyboard shortcut
    [self.app typeKey:@"," modifierFlags:XCUIKeyModifierCommand];
}

- (XCUIElement *)waitForPreferencesWindow {
    // DBPrefsWindowController's window is an NSPanel with styleMask (Titled |
    // Closable | Miniaturizable) and no Resizable bit. AppKit reports that
    // combination to the accessibility API with subrole AXDialog, so XCUITest
    // classifies it as XCUIElementTypeDialog rather than XCUIElementTypeWindow
    // — it never shows up in `self.app.windows` no matter how long we wait,
    // which is why the previous windows.count-based wait always timed out.
    // It is still a top-level element, just under `self.app.dialogs`.
    //
    // Each accessibility query round-trips through the accessibility server;
    // on a slow/contended runner that round trip can itself take several
    // seconds. A manual loop like `for i<50 { count; sleep(0.1) }` pays that
    // per-call cost up to 50 times over (minutes, not seconds) before giving
    // up. expectationForPredicate: polls internally without our loop
    // multiplying the cost, and the explicit timeout below bounds the total
    // wait to a fixed, predictable budget regardless of how slow each
    // individual accessibility call is.
    NSPredicate *hasDialog = [NSPredicate predicateWithFormat:@"count > 0"];
    XCTNSPredicateExpectation *expectation =
        [[XCTNSPredicateExpectation alloc] initWithPredicate:hasDialog
                                                       object:self.app.dialogs];
    XCTWaiter *waiter = [[XCTWaiter alloc] init];
    [waiter waitForExpectations:@[expectation] timeout:15];

    return self.app.dialogs.firstMatch;
}

- (void)saveWindowElementScreenshotNamed:(NSString *)name element:(XCUIElement *)element {
    // Re-fetch the prefs dialog to avoid a stale element reference (the
    // window title changes when switching tabs, invalidating predicate matches).
    XCUIElement *target = self.app.dialogs.firstMatch.exists ? self.app.dialogs.firstMatch : element;
    if (!target.exists) {
        NSLog(@"[GitXScreenshotTests] Preferences window not found for screenshot '%@'", name);
        return;
    }
    XCUIScreenshot *screenshot = [target screenshot];
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (XCUIElement *)findPrefsTabButton:(NSString *)label inWindow:(XCUIElement *)window {
    // NSPanel toolbars are not always in .toolbars — search the full descendant tree.
    XCUIElement *btn = [window.toolbars.buttons elementMatchingPredicate:
        [NSPredicate predicateWithFormat:@"label == %@ OR title == %@ OR identifier == %@",
         label, label, label]];
    if (btn.exists) return btn;

    // Broader: any button or toolbar button anywhere in the window
    btn = [window.buttons elementMatchingPredicate:
        [NSPredicate predicateWithFormat:@"label == %@ OR title == %@", label, label]];
    if (btn.exists) return btn;

    // Fallback: search all descendants
    NSPredicate *pred = [NSPredicate predicateWithFormat:
        @"(elementType == %d OR elementType == %d) AND (label == %@ OR title == %@)",
        XCUIElementTypeButton, XCUIElementTypeToolbarButton, label, label];
    XCUIElementQuery *q = [window descendantsMatchingType:XCUIElementTypeAny];
    btn = [q elementMatchingPredicate:pred];
    return btn;
}

- (void)testSettingsGeneralTabScreenshot {
    XCTAssertTrue([self waitForWindow], @"Main window must appear before opening Preferences");

    [self openPreferencesWindow];
    XCUIElement *prefsWindow = [self waitForPreferencesWindow];
    XCTAssertTrue(prefsWindow.exists, @"Preferences window must appear");

    XCUIElement *btn = [self findPrefsTabButton:@"General" inWindow:prefsWindow];
    if (btn.exists) {
        [btn click];
        [NSThread sleepForTimeInterval:0.6];
        // Re-fetch — title changed to "General" after click
        prefsWindow = self.app.dialogs.firstMatch;
    } else {
        NSLog(@"[GitXScreenshotTests] General toolbar button not found");
    }

    [self saveWindowElementScreenshotNamed:@"settings-general" element:prefsWindow];

    if (self.app.dialogs.firstMatch.exists) {
        [self.app.dialogs.firstMatch typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
        [NSThread sleepForTimeInterval:0.3];
    }
}

- (void)testSettingsIntegrationTabScreenshot {
    XCTAssertTrue([self waitForWindow], @"Main window must appear before opening Preferences");

    [self openPreferencesWindow];
    XCUIElement *prefsWindow = [self waitForPreferencesWindow];
    XCTAssertTrue(prefsWindow.exists, @"Preferences window must appear");

    XCUIElement *btn = [self findPrefsTabButton:@"Integration" inWindow:prefsWindow];
    if (btn.exists) {
        [btn click];
        [NSThread sleepForTimeInterval:0.6];
        // Re-fetch — title changed to "Integration" after click
        prefsWindow = self.app.dialogs.firstMatch;
    } else {
        NSLog(@"[GitXScreenshotTests] Integration toolbar button not found");
    }

    [self saveWindowElementScreenshotNamed:@"settings-integration" element:prefsWindow];

    if (self.app.dialogs.firstMatch.exists) {
        [self.app.dialogs.firstMatch typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
        [NSThread sleepForTimeInterval:0.3];
    }
}

@end

