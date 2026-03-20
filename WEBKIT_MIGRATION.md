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

### ⚠️ MUST IMPLEMENT: runCommand

**Location**: `Classes/Controllers/PBWebController.m:218-244`

**Issue**: The `runCommand` method allows JavaScript to execute git commands. It's currently stubbed out.

**What's Needed**:
1. Add message handler for `runCommand` in `setupJavaScriptBridge`
2. Implement handler in `userContentController:didReceiveScriptMessage:`
3. Parse command arguments from message body (array of strings)
4. Execute git command via `PBTask`
5. Return results to JavaScript via callback

**Example Implementation**:
```objc
// In setupJavaScriptBridge
[contentController addScriptMessageHandler:self name:@"runCommand"];

// In userContentController:didReceiveScriptMessage:
else if ([message.name isEqualToString:@"runCommand"]) {
    NSDictionary *msgDict = message.body;
    NSArray *arguments = msgDict[@"arguments"];
    NSString *callbackId = msgDict[@"callbackId"];
    PBGitRepository *repo = msgDict[@"repository"]; // Need to pass repository reference
    
    PBTask *task = [repo taskWithArguments:arguments];
    [task performTaskWithCompletionHandler:^(NSData *readData, NSError *error) {
        if (error) {
            // Call error callback
            NSString *script = [NSString stringWithFormat:@"if (window._callbacks['%@']) { window._callbacks['%@'](new Error('%@')); }", 
                callbackId, callbackId, error.localizedDescription];
            [self evaluateJavaScript:script completionHandler:nil];
        } else {
            // Convert data to string and call success callback
            NSString *output = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
            // Need to JSON-encode output for safe injection
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[output] options:0 error:nil];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            jsonString = [jsonString substringWithRange:NSMakeRange(1, jsonString.length - 2)]; // Remove array brackets
            NSString *script = [NSString stringWithFormat:@"if (window._callbacks['%@']) { window._callbacks['%@'](null, %@); }", 
                callbackId, callbackId, jsonString];
            [self evaluateJavaScript:script completionHandler:nil];
        }
    }];
}
```

**JavaScript Changes Needed**:
- Find all calls to `Controller.runCommand` or similar in HTML/JS files
- Update to use new message-based API

### ⚠️ MUST IMPLEMENT: Index Object Injection

**Location**: `Classes/Controllers/PBWebChangesController.m:44-52`

**Issue**: The `Index` object needs to be exposed to JavaScript for commit view functionality.

**What's Needed**:
1. Determine what methods JavaScript calls on the `Index` object
2. Create message handlers for each method
3. Inject JavaScript stubs that forward calls to message handlers
4. Implement Objective-C handlers that call methods on `controller.index`

**Steps**:
1. Search JavaScript files for `Index.` to find all method calls
2. Create message handler for each method
3. In `didLoad`, inject JavaScript:
```javascript
window.Index = {
    someMethod: function(args, callback) {
        var callbackId = 'cb_' + (++window._callbackId);
        window._callbacks[callbackId] = callback;
        webkit.messageHandlers.indexSomeMethod.postMessage({args: args, callbackId: callbackId});
    }
    // ... other methods
};
```

## Known Limitations

1. **Context Menus**: WKWebView doesn't provide DOM access, so context menu functionality is severely limited compared to WebView.

2. **Timing**: Asynchronous JavaScript bridge may affect timing-sensitive code. Look for race conditions.

3. **DOM Access**: Any code that directly accessed the DOM (e.g., `mainFrame.DOMDocument`) no longer works. Use `evaluateJavaScript` to run JavaScript that queries the DOM.

## Testing Checklist

- [ ] Verify all views load correctly
- [ ] Test JavaScript console logging works
- [ ] Test dark/light mode switching
- [ ] Verify `gitx://` URLs load git objects
- [ ] Test isReachable functionality
- [ ] Test isFeatureEnabled functionality
- [ ] **Test git command execution from JavaScript** (currently broken)
- [ ] **Test commit view operations** (currently broken)
- [ ] Test history view navigation
- [ ] Test file diff display
- [ ] Test keyboard shortcuts
- [ ] Test copy operations
- [ ] Verify window resizing works

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
