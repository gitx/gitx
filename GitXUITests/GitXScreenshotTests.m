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

// - (void)testFullScreenScreenshot {
//     // Capture the entire screen — useful for catching system-level visual regressions
//     [NSThread sleepForTimeInterval:1.0]; // let the app settle
//     [self saveScreenshotNamed:@"full-screen"];
// }

- (void)testCommitContextMenuScreenshot {
    if (![self waitForWindow]) { return; }

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
    if (gitxMenu.exists) {
        [gitxMenu click];
        XCUIElement *prefsItem = self.app.menuItems[@"Preferences…"];
        if (!prefsItem.exists) {
            prefsItem = self.app.menuItems[@"Settings…"];
        }
        if (prefsItem.exists) {
            [prefsItem click];
            return;
        }
        // Dismiss the menu before falling back
        [appMenu typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
    }
    // Fallback: keyboard shortcut
    [self.app typeKey:@"," modifierFlags:XCUIKeyModifierCommand];
}

- (XCUIElement *)waitForPreferencesWindow {
    // DBPrefsWindowController sets the window title to the active tab label
    // ("General", "Integration", "Updates") — not "Preferences" or "Settings".
    // Wait for any second window to appear (index 1), which is the prefs panel.
    NSPredicate *appeared = [NSPredicate predicateWithFormat:@"windows.count > 1"];
    BOOL ok = [self expectationForPredicate:appeared
                        evaluatedWithObject:self.app
                                    handler:nil] != nil;
    (void)ok;
    // Poll manually — waitForExpectations requires XCTestCase context
    for (int i = 0; i < 50; i++) {
        if (self.app.windows.count > 1) {
            return [self.app.windows elementBoundByIndex:1];
        }
        [NSThread sleepForTimeInterval:0.1];
    }
    // Last resort: return by index anyway (will be non-existent if not found)
    return [self.app.windows elementBoundByIndex:1];
}

- (void)saveWindowElementScreenshotNamed:(NSString *)name element:(XCUIElement *)element {
    // Re-fetch the prefs window by index to avoid stale element references
    // (the window title changes when switching tabs, invalidating predicate matches).
    XCUIElement *target = (self.app.windows.count > 1)
        ? [self.app.windows elementBoundByIndex:1]
        : element;
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

    if (prefsWindow.exists) {
        XCUIElement *btn = [self findPrefsTabButton:@"General" inWindow:prefsWindow];
        if (btn.exists) {
            [btn click];
            [NSThread sleepForTimeInterval:0.6];
            // Re-fetch by index — title changed to "General" after click
            prefsWindow = [self.app.windows elementBoundByIndex:1];
        } else {
            NSLog(@"[GitXScreenshotTests] General toolbar button not found");
        }
    } else {
        NSLog(@"[GitXScreenshotTests] Preferences window not found for General tab");
    }

    [self saveWindowElementScreenshotNamed:@"settings-general" element:prefsWindow];

    if (self.app.windows.count > 1) {
        [[self.app.windows elementBoundByIndex:1] typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
        [NSThread sleepForTimeInterval:0.3];
    }
}

- (void)testSettingsIntegrationTabScreenshot {
    XCTAssertTrue([self waitForWindow], @"Main window must appear before opening Preferences");

    [self openPreferencesWindow];
    XCUIElement *prefsWindow = [self waitForPreferencesWindow];

    if (prefsWindow.exists) {
        XCUIElement *btn = [self findPrefsTabButton:@"Integration" inWindow:prefsWindow];
        if (btn.exists) {
            [btn click];
            [NSThread sleepForTimeInterval:0.6];
            // Re-fetch by index — title changed to "Integration" after click
            prefsWindow = [self.app.windows elementBoundByIndex:1];
        } else {
            NSLog(@"[GitXScreenshotTests] Integration toolbar button not found");
        }
    } else {
        NSLog(@"[GitXScreenshotTests] Preferences window not found for Integration tab");
    }

    [self saveWindowElementScreenshotNamed:@"settings-integration" element:prefsWindow];

    if (self.app.windows.count > 1) {
        [[self.app.windows elementBoundByIndex:1] typeKey:XCUIKeyboardKeyEscape modifierFlags:0];
        [NSThread sleepForTimeInterval:0.3];
    }
}

@end

