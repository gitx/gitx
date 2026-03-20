//
//  PBWebController.m
//  GitX
//
//  Created by Pieter de Bie on 08-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBWebController.h"
#import "PBGitRepository.h"
#import "PBGitRepository_PBGitBinarySupport.h"
#import "PBGitXProtocol.h"
#import "PBGitXSchemeHandler.h"
#import "PBGitDefaults.h"

#include <SystemConfiguration/SCNetworkReachability.h>

@interface PBWebController () <WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler>
@property (strong, nonatomic) PBGitXSchemeHandler *schemeHandler;
- (void)preferencesChangedWithNotification:(NSNotification *)theNotification;
- (void)setupJavaScriptBridge;
@end

@implementation PBWebController

@synthesize startFile, repository;

- (void)awakeFromNib
{
	// WKWebView configuration must be set before creation, but since the view comes from XIB,
	// we need to replace it with a properly configured one
	if (self.view) {
		NSView *superview = self.view.superview;
		NSRect frame = self.view.frame;
		NSUInteger autoresizingMask = self.view.autoresizingMask;
		
		// Create configuration with custom scheme handler
		WKWebViewConfiguration *configuration = [[WKWebViewConfiguration alloc] init];
		self.schemeHandler = [[PBGitXSchemeHandler alloc] init];
		self.schemeHandler.repository = self.repository;
		[configuration setURLSchemeHandler:self.schemeHandler forURLScheme:@"gitx"];
		
		// Create new WKWebView with configuration
		WKWebView *newView = [[WKWebView alloc] initWithFrame:frame configuration:configuration];
		newView.autoresizingMask = autoresizingMask;
		newView.navigationDelegate = self;
		newView.UIDelegate = self;
		
		// Replace the old view
		[self.view removeFromSuperview];
		[superview addSubview:newView];
		self.view = newView;
	}
	
	NSString *path = [NSString stringWithFormat:@"html/views/%@", startFile];
	NSString *file = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:path];
	
	if (!file) {
		NSLog(@"ERROR: Could not find index.html in bundle at path: %@", path);
		NSLog(@"ERROR: startFile = %@", startFile);
		NSLog(@"ERROR: This is a critical error. The view will not load correctly.");
		// We continue to initialize callbacks and JavaScript bridge to prevent crashes,
		// but the view will remain empty. Check console for this error message.
	}
	
	NSURL *fileURL = file ? [NSURL fileURLWithPath:file] : nil;
	NSURL *directoryURL = [fileURL URLByDeletingLastPathComponent];
	
	callbacks = [NSMapTable mapTableWithKeyOptions:(NSPointerFunctionsObjectPointerPersonality | NSPointerFunctionsStrongMemory) valueOptions:(NSPointerFunctionsObjectPointerPersonality | NSPointerFunctionsStrongMemory)];

	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self
		   selector:@selector(preferencesChangedWithNotification:)
			   name:NSUserDefaultsDidChangeNotification
			 object:nil];

	[nc addObserver:self
		   selector:@selector(windowWillStartLiveResizeWithNotification:)
			   name:NSWindowWillStartLiveResizeNotification
			 object:self.view.window];

	[nc addObserver:self
		   selector:@selector(windowDidEndLiveResizeWithNotification:)
			   name:NSWindowDidEndLiveResizeNotification
			 object:self.view.window];

	[nc addObserver:self
		   selector:@selector(effectiveAppearanceDidChange:)
			   name:PBEffectiveAppearanceChanged
			 object:nil];

	finishedLoading = NO;
	
	// Set up JavaScript bridge
	[self setupJavaScriptBridge];
	
	// Load the request
	if (fileURL && directoryURL) {
		[self.view loadFileURL:fileURL allowingReadAccessToURL:directoryURL];
	} else {
		NSLog(@"ERROR: Cannot load content - invalid file URL (fileURL: %@, directoryURL: %@)", fileURL, directoryURL);
	}
}

- (void)setupJavaScriptBridge
{
	// Add script message handlers for communication from JavaScript to Objective-C
	WKUserContentController *contentController = self.view.configuration.userContentController;
	[contentController addScriptMessageHandler:self name:@"log"];
	[contentController addScriptMessageHandler:self name:@"isReachable"];
	[contentController addScriptMessageHandler:self name:@"isFeatureEnabled"];
	[contentController addScriptMessageHandler:self name:@"runCommand"];
	[contentController addScriptMessageHandler:self name:@"makeWebViewFirstResponder"];
}

- (void)evaluateJavaScript:(NSString *)script completionHandler:(void (^)(id result, NSError *error))completionHandler
{
	[self.view evaluateJavaScript:script completionHandler:completionHandler];
}

- (void)callJavaScriptFunction:(NSString *)functionName withArguments:(NSArray *)arguments completionHandler:(void (^)(id result, NSError *error))completionHandler
{
	NSMutableString *script = [NSMutableString stringWithFormat:@"if (typeof %@ === 'function') { %@(", functionName, functionName];
	
	if (arguments && arguments.count > 0) {
		for (NSUInteger i = 0; i < arguments.count; i++) {
			id arg = arguments[i];
			
			// Convert arguments to JSON for safe serialization
			NSError *jsonError = nil;
			NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[arg] options:0 error:&jsonError];
			if (!jsonError && jsonData) {
				NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
				// Extract the value from the array wrapper [value] -> value
				if (jsonString.length > 2) {
					jsonString = [jsonString substringWithRange:NSMakeRange(1, jsonString.length - 2)];
				}
				[script appendString:jsonString];
			} else {
				// Fallback to null if serialization fails
				NSLog(@"Failed to serialize argument: %@, error: %@", arg, jsonError);
				[script appendString:@"null"];
			}
			
			if (i < arguments.count - 1) {
				[script appendString:@", "];
			}
		}
	}
	
	[script appendString:@"); }"];
	
	[self evaluateJavaScript:script completionHandler:completionHandler];
}

- (void)effectiveAppearanceDidChange:(NSNotification *)notif
{
	NSString *mode = [NSApp isDarkMode] ? @"DARK" : @"LIGHT";
	[self callJavaScriptFunction:@"setAppearance" withArguments:@[mode] completionHandler:nil];
}

- (void)closeView
{
	if (self.view) {
		NSString *script = @"if (typeof Controller !== 'undefined') { Controller = null; }";
		[self evaluateJavaScript:script completionHandler:nil];
		
		// Remove script message handlers
		WKUserContentController *contentController = self.view.configuration.userContentController;
		[contentController removeScriptMessageHandlerForName:@"log"];
		[contentController removeScriptMessageHandlerForName:@"isReachable"];
		[contentController removeScriptMessageHandlerForName:@"isFeatureEnabled"];
		[contentController removeScriptMessageHandlerForName:@"runCommand"];
		[contentController removeScriptMessageHandlerForName:@"makeWebViewFirstResponder"];
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didLoad
{
}

#pragma mark Delegate methods

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
	// Inject the Controller object into JavaScript with proper method stubs
	// These stubs will post messages back to Objective-C via webkit.messageHandlers
	// Using a callback registry to handle asynchronous responses
	NSString *script = @"\
window._callbacks = {};\
window._callbackId = 0;\
window.Controller = {\
    log: function(message) { webkit.messageHandlers.log.postMessage(message); },\
    isReachable: function(hostname, callback) {\
        var callbackId = 'cb_' + (++window._callbackId);\
        window._callbacks[callbackId] = callback;\
        webkit.messageHandlers.isReachable.postMessage({hostname: hostname, callbackId: callbackId});\
    },\
    isFeatureEnabled: function(feature, callback) {\
        var callbackId = 'cb_' + (++window._callbackId);\
        window._callbacks[callbackId] = callback;\
        webkit.messageHandlers.isFeatureEnabled.postMessage({feature: feature, callbackId: callbackId});\
    },\
    makeWebViewFirstResponder: function() { webkit.messageHandlers.makeWebViewFirstResponder.postMessage(null); }\
};";
	
	[self evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
		if (error) {
			NSLog(@"Failed to inject Controller: %@", error);
		}
		// Set up the bridge by exposing controller methods
		self->finishedLoading = YES;
		if ([self respondsToSelector:@selector(didLoad)])
			[self performSelector:@selector(didLoad)];
		[self effectiveAppearanceDidChange:nil];
	}];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
	NSString *scheme = [[navigationAction.request URL] scheme];
	if ([scheme compare:@"http"] == NSOrderedSame ||
		[scheme compare:@"https"] == NSOrderedSame) {
		decisionHandler(WKNavigationActionPolicyCancel);
		[[NSWorkspace sharedWorkspace] openURL:[navigationAction.request URL]];
	} else {
		decisionHandler(WKNavigationActionPolicyAllow);
	}
}

#pragma mark WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
	if ([message.name isEqualToString:@"log"]) {
		[self log:message.body];
	} else if ([message.name isEqualToString:@"isReachable"]) {
		// Extract hostname and callback ID from message body
		NSDictionary *msgDict = message.body;
		NSString *hostname = msgDict[@"hostname"];
		NSString *callbackId = msgDict[@"callbackId"];
		
		BOOL reachable = [self isReachable:hostname];
		NSString *callbackScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](%@); delete window._callbacks['%@']; }", 
			callbackId, callbackId, reachable ? @"true" : @"false", callbackId];
		[self evaluateJavaScript:callbackScript completionHandler:nil];
	} else if ([message.name isEqualToString:@"isFeatureEnabled"]) {
		// Extract feature and callback ID from message body
		NSDictionary *msgDict = message.body;
		NSString *feature = msgDict[@"feature"];
		NSString *callbackId = msgDict[@"callbackId"];
		
		BOOL enabled = [self isFeatureEnabled:feature];
		NSString *callbackScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](%@); delete window._callbacks['%@']; }", 
			callbackId, callbackId, enabled ? @"true" : @"false", callbackId];
		[self evaluateJavaScript:callbackScript completionHandler:nil];
	} else if ([message.name isEqualToString:@"runCommand"]) {
		// Handle runCommand - execute git commands from JavaScript
		NSDictionary *msgDict = message.body;
		NSArray *arguments = msgDict[@"arguments"];
		NSString *callbackId = msgDict[@"callbackId"];
		
		if (!arguments || ![arguments isKindOfClass:[NSArray class]]) {
			NSLog(@"runCommand: Invalid arguments - expected array, got %@", arguments);
			NSString *errorScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](new Error('Invalid arguments')); delete window._callbacks['%@']; }", 
				callbackId, callbackId, callbackId];
			[self evaluateJavaScript:errorScript completionHandler:nil];
			return;
		}
		
		if (!self.repository) {
			NSLog(@"runCommand: No repository available");
			NSString *errorScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](new Error('No repository available')); delete window._callbacks['%@']; }", 
				callbackId, callbackId, callbackId];
			[self evaluateJavaScript:errorScript completionHandler:nil];
			return;
		}
		
		NSLog(@"runCommand: Executing git command with args: %@", arguments);
		
		PBTask *task = [self.repository taskWithArguments:arguments];
		[task performTaskWithCompletionHandler:^(NSData *_Nullable readData, NSError *_Nullable error) {
			if (error) {
				NSLog(@"runCommand error: %@", error);
				// JSON-encode error message for safe JavaScript injection
				NSString *errorMsg = error.localizedDescription ?: @"Unknown error";
				NSError *jsonError = nil;
				NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[errorMsg] options:0 error:&jsonError];
				NSString *jsonString = nil;
				if (!jsonError && jsonData) {
					jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
					// Remove array brackets [value] -> value
					if (jsonString.length > 2) {
						jsonString = [jsonString substringWithRange:NSMakeRange(1, jsonString.length - 2)];
					}
				} else {
					jsonString = @"\"Error encoding failed\"";
				}
				NSString *errorScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](new Error(%@)); delete window._callbacks['%@']; }", 
					callbackId, callbackId, jsonString, callbackId];
				dispatch_async(dispatch_get_main_queue(), ^{
					[self evaluateJavaScript:errorScript completionHandler:nil];
				});
			} else {
				// Convert data to string and call success callback
				NSString *output = [[NSString alloc] initWithData:readData encoding:NSUTF8StringEncoding];
				if (!output) {
					output = @"";
				}
				
				// JSON-encode output for safe injection
				NSError *jsonError = nil;
				NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[output] options:0 error:&jsonError];
				if (jsonError || !jsonData) {
					NSLog(@"runCommand: Failed to serialize output: %@", jsonError);
					NSString *errorScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](new Error('Failed to serialize output')); delete window._callbacks['%@']; }", 
						callbackId, callbackId, callbackId];
					dispatch_async(dispatch_get_main_queue(), ^{
						[self evaluateJavaScript:errorScript completionHandler:nil];
					});
					return;
				}
				
				NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
				// Remove array brackets [value] -> value
				if (jsonString.length > 2) {
					jsonString = [jsonString substringWithRange:NSMakeRange(1, jsonString.length - 2)];
				}
				
				// Call JavaScript callback: callback(null, output)
				NSString *successScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](null, %@); delete window._callbacks['%@']; }", 
					callbackId, callbackId, jsonString, callbackId];
				dispatch_async(dispatch_get_main_queue(), ^{
					[self evaluateJavaScript:successScript completionHandler:nil];
				});
			}
		}];
	} else if ([message.name isEqualToString:@"makeWebViewFirstResponder"]) {
		[self makeWebViewFirstResponder];
	}
}

#pragma mark Functions to be used from JavaScript

- (void)log:(NSString *)logMessage
{
	NSLog(@"%@", logMessage);
}

- (BOOL)isReachable:(NSString *)hostname
{
	SCNetworkReachabilityRef target;
	SCNetworkConnectionFlags flags = 0;
	Boolean reachable;
	target = SCNetworkReachabilityCreateWithName(NULL, [hostname cStringUsingEncoding:NSASCIIStringEncoding]);
	reachable = SCNetworkReachabilityGetFlags(target, &flags);
	CFRelease(target);

	if (!reachable)
		return FALSE;

	// If a connection is required, then it's not reachable
	if (flags & (kSCNetworkFlagsConnectionRequired | kSCNetworkFlagsConnectionAutomatic | kSCNetworkFlagsInterventionRequired))
		return FALSE;

	return flags > 0;
}

- (BOOL)isFeatureEnabled:(NSString *)feature
{
	if ([feature isEqualToString:@"gravatar"])
		return [PBGitDefaults isGravatarEnabled];
	else if ([feature isEqualToString:@"gist"])
		return [PBGitDefaults isGistEnabled];
	else if ([feature isEqualToString:@"confirmGist"])
		return [PBGitDefaults confirmPublicGists];
	else if ([feature isEqualToString:@"publicGist"])
		return [PBGitDefaults isGistPublic];
	else
		return YES;
}

#pragma mark Using async function from JS

- (void)runCommand:(WebScriptObject *)arguments inRepository:(PBGitRepository *)repo callBack:(WebScriptObject *)callBack
{
	// TODO: Critical - This method needs complete refactoring for WKWebView
	// The WebScriptObject-based approach doesn't work with WKWebView's message passing
	// 
	// Required changes:
	// 1. Convert this to use WKScriptMessageHandler to receive command arrays
	// 2. Use evaluateJavaScript to call back with results instead of WebScriptObject
	// 3. Update JavaScript code to use webkit.messageHandlers.runCommand.postMessage()
	//
	// This is critical functionality - without it, git operations from JavaScript won't work
	NSLog(@"ERROR: runCommand not implemented for WKWebView - git operations from JavaScript will fail");
	
	/* Original implementation for reference:
	int length = [[arguments valueForKey:@"length"] intValue];
	NSMutableArray *realArguments = [NSMutableArray arrayWithCapacity:length];
	int i = 0;
	for (i = 0; i < length; i++)
		[realArguments addObject:[arguments webScriptValueAtIndex:i]];

	PBTask *task = [repo taskWithArguments:realArguments];
	[task performTaskWithCompletionHandler:^(NSData *_Nullable readData, NSError *_Nullable error) {
		if (error) {
			NSLog(@"error: %@", error);
			return;
		}
		// Need to call JavaScript callback with results
		[callBack callWebScriptMethod:@"call" withArguments:@[ @"", readData ]];
	}];
	*/
}

- (void)preferencesChanged
{
}

- (void)makeWebViewFirstResponder
{
	[self.view.window makeFirstResponder:self.view];
}


#pragma mark - Notifications

- (void)preferencesChangedWithNotification:(NSNotification *)theNotification
{
	[self preferencesChanged];
}

- (void)windowWillStartLiveResizeWithNotification:(NSNotification *)theNotification
{
	self.view.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin | NSViewHeightSizable;
}

- (void)windowDidEndLiveResizeWithNotification:(NSNotification *)theNotification
{
	self.view.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin | NSViewWidthSizable | NSViewHeightSizable;
	self.view.frame = self.view.superview.bounds;
}

@end
