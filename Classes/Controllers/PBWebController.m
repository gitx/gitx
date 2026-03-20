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
	NSString *path = [NSString stringWithFormat:@"html/views/%@", startFile];
	NSString *file = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:path];
	NSURL *fileURL = [NSURL fileURLWithPath:file];
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

	// Configure WKWebView
	self.view.navigationDelegate = self;
	self.view.UIDelegate = self;
	
	// Set up custom scheme handler for gitx:// URLs
	self.schemeHandler = [[PBGitXSchemeHandler alloc] init];
	self.schemeHandler.repository = self.repository;
	[self.view.configuration setURLSchemeHandler:self.schemeHandler forURLScheme:@"gitx"];
	
	// Set up JavaScript bridge
	[self setupJavaScriptBridge];
	
	// Load the request
	[self.view loadFileURL:fileURL allowingReadAccessToURL:directoryURL];
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
			if ([arg isKindOfClass:[NSString class]]) {
				// Escape string and wrap in quotes
				NSString *escapedString = [(NSString *)arg stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
				escapedString = [escapedString stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"];
				escapedString = [escapedString stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
				escapedString = [escapedString stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
				[script appendFormat:@"'%@'", escapedString];
			} else if ([arg isKindOfClass:[NSNumber class]]) {
				[script appendString:[arg stringValue]];
			} else {
				// For complex objects, convert to JSON
				NSError *jsonError = nil;
				NSData *jsonData = [NSJSONSerialization dataWithJSONObject:arg options:0 error:&jsonError];
				if (!jsonError && jsonData) {
					NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
					[script appendString:jsonString];
				} else {
					[script appendString:@"null"];
				}
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
	NSString *script = [NSString stringWithFormat:@"if (typeof setAppearance === 'function') { setAppearance('%@'); }", mode];
	[self evaluateJavaScript:script completionHandler:nil];
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
	// Inject the Controller object into JavaScript
	NSString *script = @"window.Controller = {};";
	[self evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
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
		BOOL reachable = [self isReachable:message.body];
		NSString *callbackScript = [NSString stringWithFormat:@"window._isReachableCallback && window._isReachableCallback(%@);", reachable ? @"true" : @"false"];
		[self evaluateJavaScript:callbackScript completionHandler:nil];
	} else if ([message.name isEqualToString:@"isFeatureEnabled"]) {
		BOOL enabled = [self isFeatureEnabled:message.body];
		NSString *callbackScript = [NSString stringWithFormat:@"window._isFeatureEnabledCallback && window._isFeatureEnabledCallback(%@);", enabled ? @"true" : @"false"];
		[self evaluateJavaScript:callbackScript completionHandler:nil];
	} else if ([message.name isEqualToString:@"runCommand"]) {
		// Handle runCommand - this is more complex and needs special handling
		// For now, log that it was called
		NSLog(@"runCommand called with message: %@", message.body);
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
	// TODO: This method needs to be refactored for WKWebView
	// The WebScriptObject-based approach doesn't work with WKWebView's message passing
	// We'll need to handle this through evaluateJavaScript callbacks instead
	NSLog(@"runCommand called - needs refactoring for WKWebView");
	
	/* Original implementation - needs conversion:
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
