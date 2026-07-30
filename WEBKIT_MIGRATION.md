# WebView to WKWebView Migration Notes

## Overview

GitX has been migrated from the deprecated `WebView` API (deprecated in macOS 10.14) to the modern `WKWebView` API. This document outlines the changes made and the remaining work required.

## What Was Changed

### Core Framework Migration

1. **PBWebController.h/m**: Base class updated to use `WKWebView`
   - Changed from `WebView *view` to `WKWebView *view`
   - Implemented `WKNavigationDelegate` and `WKUIDelegate` instead of old WebKit delegates
   - Added `WKScriptMessageHandler` for JavaScript-to-Objective-C communication

2. **JavaScript Bridge**:
   - **Old approach**: Synchronous `windowScriptObject` with direct method calls
   - **New approach**: Asynchronous message passing via `webkit.messageHandlers`
   - Implemented callback registry pattern (`window._callbacks`) for handling async responses

3. **Custom URL Scheme**:
   - Created `PBGitXSchemeHandler` implementing `WKURLSchemeHandler`
   - Replaces `NSURLProtocol` which WKWebView doesn't support
   - Handles `gitx://` URLs for loading git objects

4. **XIB Files**:
   - Updated `PBGitHistoryView.xib`, `PBGitCommitView.xib`, `PBDiffWindow.xib`
   - Changed `<webView>` tags to `<wkWebView>`
   - Updated delegate connections to use WKWebView equivalents
   - Views are programmatically replaced to allow custom configuration

### Subclass Updates

1. **PBWebHistoryController**: 
   - All `windowScriptObject` calls converted to `callJavaScriptFunction`
   - DOM access removed (not supported in WKWebView)
   - Context menus simplified due to lack of DOM access

2. **PBWebChangesController**:
   - Delegate methods removed (WebEditingDelegate not available)
   - JavaScript calls converted to async pattern

3. **GLFileView**:
   - Updated script calls to use new helpers

## Critical Missing Functionality

### ✅ IMPLEMENTED: runCommand

**Location**: `Classes/Controllers/PBWebController.m:257-325`

**Status**: ✅ **COMPLETE** - Fully implemented in commit c25ec57

**Implementation**:
1. ✅ Message handler registered for `runCommand` in `setupJavaScriptBridge`
2. ✅ Handler implemented in `userContentController:didReceiveScriptMessage:`
3. ✅ Parses command arguments from message body (array of strings)
4. ✅ Executes git commands via `PBTask` asynchronously
5. ✅ Returns results to JavaScript via callback with proper error handling
6. ✅ JSON-encodes output for safe injection
7. ✅ Uses `dispatch_async` for main thread safety
8. ✅ Validates arguments and repository availability

**Usage**:
```javascript
// JavaScript can now call git commands:
Controller.runCommand(['log', '--oneline', '-10'], function(error, result) {
    if (error) {
        console.error('Git command failed:', error);
    } else {
        console.log('Git output:', result);
    }
});
```

**No JavaScript changes needed** - the Controller object is properly injected with runCommand support.

### ⚠️ PARTIAL: Index Object Injection

**Location**: `Classes/Controllers/PBWebChangesController.m:45-149`

**Status**: ⚠️ **PARTIAL** - Stub implemented in commit 8cd2d88, async handler ready

**What's Implemented**:
1. ✅ Override `setupJavaScriptBridge` to register `indexDiffForFile` message handler
2. ✅ Implement `userContentController:didReceiveScriptMessage:` for Index methods
3. ✅ Message handler finds files and calls `[controller.index diffForFile:staged:contextLines:]`
4. ✅ Returns diffs via JSON-encoded JavaScript callbacks
5. ✅ Inject stub `window.Index` object in `didLoad` to prevent JavaScript errors

**What's Missing**:
The old WebView API supported synchronous JavaScript method calls, but WKWebView is async-only. The JavaScript code in `Resources/html/views/commit/commit.js` expects synchronous return values:

```javascript
// Current JavaScript (expects synchronous return):
var changes = Index.diffForFile_staged_contextLines_(file, cached, contextLines);
displayDiff(changes, cached);  // Uses result immediately
```

**Current Workaround**:
The stub returns an empty string, preventing JavaScript errors. The message handler is ready for async calls once JavaScript is refactored.

**What's Needed for Full Functionality**:
1. Refactor `Resources/html/views/commit/commit.js` to use async callbacks:
```javascript
// Refactored approach (async):
Index.diffForFile_staged_contextLines_(file, cached, contextLines, function(diff) {
    if (diff) {
        displayDiff(diff, cached);
    }
});
```

2. Update the Index object injection to use the message handler:
```javascript
window.Index = {
    diffForFile_staged_contextLines_: function(file, staged, contextLines, callback) {
        var callbackId = 'cb_' + (++window._callbackId);
        window._callbacks[callbackId] = callback;
        webkit.messageHandlers.indexDiffForFile.postMessage({
            file: file,
            staged: staged,
            contextLines: contextLines,
            callbackId: callbackId
        });
    }
};
```

**Impact**:
- ✅ Commit view loads without JavaScript errors
- ⚠️  File diffs don't display (returns empty string)
- ✅ Staging/unstaging files still works (uses different code path)
- 📝 TODO: JavaScript refactoring for full diff display functionality

## Known Limitations

1. **Context Menus**: WKWebView doesn't provide DOM access, so context menu functionality is severely limited compared to WebView.

2. **Timing**: Asynchronous JavaScript bridge may affect timing-sensitive code. Look for race conditions.

3. **DOM Access**: Any code that directly accessed the DOM (e.g., `mainFrame.DOMDocument`) no longer works. Use `evaluateJavaScript` to run JavaScript that queries the DOM.

## Testing Checklist

- [x] Verify all views load correctly (with error logging)
- [x] Test JavaScript console logging works
- [x] Test dark/light mode switching  
- [x] Verify `gitx://` URLs load git objects (PBGitXSchemeHandler implemented)
- [x] Test isReachable functionality
- [x] Test isFeatureEnabled functionality
- [x] **Test git command execution from JavaScript** ✅ **WORKING** (runCommand implemented)
- [ ] **Test commit view operations** ⚠️ **PARTIAL** (Index stub prevents errors, diff display needs JS refactoring)
- [ ] Test history view navigation
- [ ] Test file diff display
- [ ] Test keyboard shortcuts
- [ ] Test copy operations
- [ ] Verify window resizing works
- [ ] Verify HTML files load from bundle (with error logging added)

## Architecture Notes

### Callback Pattern

WKWebView's message passing is one-way (JS → Obj-C). For bidirectional communication, we use a callback registry:

1. JavaScript generates unique callback ID
2. JavaScript stores callback function in `window._callbacks[id]`
3. JavaScript posts message with callback ID
4. Objective-C processes request
5. Objective-C calls back by evaluating JavaScript: `window._callbacks[id](result)`
6. Callback is deleted from registry

This pattern supports concurrent operations unlike the old global callback approach.

### Configuration Immutability

WKWebView's configuration (including URL scheme handlers) cannot be modified after creation. Since XIBs create the view first, we:

1. Let XIB create initial WKWebView
2. In `awakeFromNib`, create new WKWebView with proper configuration
3. Replace XIB view with configured view
4. Maintain same frame, superview, and autoresizing mask

## References

- [WebView to WKWebView Migration Guide](https://developer.apple.com/documentation/webkit/wkwebview)
- [WKScriptMessageHandler Protocol](https://developer.apple.com/documentation/webkit/wkscriptmessagehandler)
- [WKURLSchemeHandler Protocol](https://developer.apple.com/documentation/webkit/wkurlschemehandler)

## Questions?

For questions about this migration, see the PR discussion or open an issue with the `webkit` label.
