//
//  PBWebChangesController.m
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBWebChangesController.h"
#import "PBGitIndex.h"

static void *const UnstagedFileSelectedContext = @"UnstagedFileSelectedContext";
static void *const CachedFileSelectedContext = @"CachedFileSelectedContext";

@interface PBWebChangesController ()
@end

@implementation PBWebChangesController

- (void)awakeFromNib
{
	selectedFile = nil;
	selectedFileIsCached = NO;

	startFile = @"commit";
	[super awakeFromNib];

	[unstagedFilesController addObserver:self forKeyPath:@"selection" options:0 context:UnstagedFileSelectedContext];
	[stagedFilesController addObserver:self forKeyPath:@"selection" options:0 context:CachedFileSelectedContext];
	
	// WKWebView doesn't have editingDelegate or UIDelegate in the same way as WebView
	// These will need to be handled differently if editing functionality is needed
}

- (void)closeView
{
	NSString *script = @"if (typeof Index !== 'undefined') { Index = null; }";
	[self evaluateJavaScript:script completionHandler:nil];
	[unstagedFilesController removeObserver:self forKeyPath:@"selection"];
	[stagedFilesController removeObserver:self forKeyPath:@"selection"];

	[super closeView];
}

- (void)setupJavaScriptBridge
{
	[super setupJavaScriptBridge];
	
	// Add message handler for Index.diffForFile_staged_contextLines_
	WKUserContentController *contentController = self.view.configuration.userContentController;
	[contentController addScriptMessageHandler:self name:@"indexDiffForFile"];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
	// Handle Index object methods
	if ([message.name isEqualToString:@"indexDiffForFile"]) {
		NSDictionary *msgDict = message.body;
		NSDictionary *fileDict = msgDict[@"file"];
		BOOL staged = [msgDict[@"staged"] boolValue];
		NSUInteger contextLines = [msgDict[@"contextLines"] unsignedIntegerValue];
		NSString *callbackId = msgDict[@"callbackId"];
		
		if (!fileDict) {
			NSLog(@"indexDiffForFile: No file provided");
			NSString *errorScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](new Error('No file provided')); delete window._callbacks['%@']; }", 
				callbackId, callbackId, callbackId];
			[self evaluateJavaScript:errorScript completionHandler:nil];
			return;
		}
		
		// Convert file dictionary back to PBChangedFile object
		// For now, we'll pass the file dict directly to showFileChanges via JavaScript
		// This is a simplified approach - in production, you'd reconstruct the PBChangedFile
		PBChangedFile *file = nil;
		
		// Find the file in our controllers
		for (PBChangedFile *f in [unstagedFilesController arrangedObjects]) {
			if ([f.path isEqualToString:fileDict[@"path"]]) {
				file = f;
				break;
			}
		}
		if (!file) {
			for (PBChangedFile *f in [stagedFilesController arrangedObjects]) {
				if ([f.path isEqualToString:fileDict[@"path"]]) {
					file = f;
					break;
				}
			}
		}
		
		if (!file) {
			NSLog(@"indexDiffForFile: File not found: %@", fileDict[@"path"]);
			NSString *errorScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](new Error('File not found')); delete window._callbacks['%@']; }", 
				callbackId, callbackId, callbackId];
			[self evaluateJavaScript:errorScript completionHandler:nil];
			return;
		}
		
		// Get the diff from the index
		NSString *diff = [controller.index diffForFile:file staged:staged contextLines:contextLines];
		
		// JSON-encode the diff for safe injection
		NSError *jsonError = nil;
		NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@[diff ?: @""] options:0 error:&jsonError];
		if (jsonError || !jsonData) {
			NSLog(@"indexDiffForFile: Failed to serialize diff: %@", jsonError);
			NSString *errorScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](new Error('Failed to serialize diff')); delete window._callbacks['%@']; }", 
				callbackId, callbackId, callbackId];
			[self evaluateJavaScript:errorScript completionHandler:nil];
			return;
		}
		
		NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		// Remove array brackets [value] -> value
		if (jsonString.length > 2) {
			jsonString = [jsonString substringWithRange:NSMakeRange(1, jsonString.length - 2)];
		}
		
		// Call JavaScript callback with the diff (error-first callback pattern)
		NSString *successScript = [NSString stringWithFormat:@"if (window._callbacks && window._callbacks['%@']) { window._callbacks['%@'](null, %@); delete window._callbacks['%@']; }", 
			callbackId, callbackId, jsonString, callbackId];
		[self evaluateJavaScript:successScript completionHandler:nil];
	} else {
		// Pass to parent implementation for other message handlers
		[super userContentController:userContentController didReceiveScriptMessage:message];
	}
}

- (void)didLoad
{
	// Inject Index object into JavaScript for WKWebView
	// Note: The old WebView API was synchronous, but WKWebView is async
	// We inject a simplified synchronous-looking wrapper that returns immediately
	// The actual implementation will need the JavaScript to be refactored for proper async
	NSString *indexObjectScript = @"\
	window.Index = {\
		diffForFile_staged_contextLines_: function(file, staged, contextLines) {\
			/* WKWebView limitation: Cannot do synchronous calls like the old WebView API.\
			   This is a stub that returns empty string.\
			   TODO: Refactor JavaScript to use async patterns. */\
			console.log('Index.diffForFile_staged_contextLines_ called - returning empty (WKWebView async limitation)');\
			return '';\
		}\
	};";
	
	[self evaluateJavaScript:indexObjectScript completionHandler:^(id result, NSError *error) {
		if (error) {
			NSLog(@"ERROR: Failed to inject Index object: %@", error);
		} else {
			NSLog(@"Index object injected (with WKWebView async limitations)");
		}
	}];
	
	[self refresh];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
	if (context != UnstagedFileSelectedContext && context != CachedFileSelectedContext) {
		return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}

	NSArrayController *otherController;
	otherController = object == unstagedFilesController ? stagedFilesController : unstagedFilesController;
	NSUInteger count = [object selectedObjects].count;
	if (count == 0) {
		if ([[otherController selectedObjects] count] == 0 && selectedFile) {
			selectedFile = nil;
			selectedFileIsCached = NO;
			[self refresh];
		}
		return;
	}

	// TODO: Move this to commitcontroller
	[otherController setSelectionIndexes:[NSIndexSet indexSet]];

	if (count > 1) {
		[self showMultiple:[object selectedObjects]];
		return;
	}

	selectedFile = [[object selectedObjects] objectAtIndex:0];
	selectedFileIsCached = object == stagedFilesController;

	[self refresh];
}

- (void)showMultiple:(NSArray *)objects
{
	[self callJavaScriptFunction:@"showMultipleFilesSelection" withArguments:[NSArray arrayWithObject:objects] completionHandler:nil];
}

- (void)refresh
{
	if (!finishedLoading)
		return;

	[self callJavaScriptFunction:@"showFileChanges"
				   withArguments:[NSArray arrayWithObjects:selectedFile ?: (id)[NSNull null],
													  [NSNumber numberWithBool:selectedFileIsCached], nil]
			   completionHandler:nil];
}

- (void)stageHunk:(NSString *)hunk reverse:(BOOL)reverse
{
	[controller.index applyPatch:hunk stage:YES reverse:reverse];
	// FIXME: Don't need a hard refresh

	[self refresh];
}

- (void)discardHunk:(NSString *)hunk
{
	[controller.index applyPatch:hunk stage:NO reverse:YES];
	[self refresh];
}

- (void)discardHunk:(NSString *)hunk altKey:(BOOL)altKey
{
	if (!altKey) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = NSLocalizedString(@"Discard hunk", @"Title of dialogue asking whether the user really wanted to press the Discard button on a hunk in the changes view");
		alert.informativeText = NSLocalizedString(@"Are you sure you wish to discard the changes in this hunk?\n\nYou cannot undo this operation.", @"Asks whether the user really wants to discard a hunk in changes view after pressing the Discard Hunk button");

		[alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK (discarding a hunk in the changes view)")];
		[alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel (discarding a hunk in the changes view)")];

		[controller.windowController confirmDialog:alert
							 suppressionIdentifier:nil
										 forAction:^{
											 [self discardHunk:hunk];
										 }];
	} else {
		[self discardHunk:hunk];
	}
}

- (void)setStateMessage:(NSString *)state
{
	[self callJavaScriptFunction:@"setState" withArguments:[NSArray arrayWithObject:state] completionHandler:nil];
}

- (void)copy:(NSString *)text
{
	NSArray *lines = [text componentsSeparatedByString:@"\n"];
	NSMutableArray *processedLines = [NSMutableArray arrayWithCapacity:lines.count - 1];
	for (int i = 0; i < lines.count; i++) {
		NSString *line = [lines objectAtIndex:i];
		if (line.length > 0) {
			[processedLines addObject:[line substringFromIndex:1]];
		} else {
			[processedLines addObject:line];
		}
	}
	NSString *result = [processedLines componentsJoinedByString:@"\n"];
	[[NSPasteboard generalPasteboard] declareTypes:[NSArray arrayWithObject:NSPasteboardTypeString] owner:nil];
	[[NSPasteboard generalPasteboard] setString:result forType:NSPasteboardTypeString];
}

// Note: WKWebView doesn't have WebEditingDelegate protocol.
// Copy functionality may need to be handled through JavaScript message handlers instead.
// Keeping these methods commented for reference but they won't be called by WKWebView.
/*
- (BOOL)webView:(WebView *)webView
	validateUserInterfaceItem:(id<NSValidatedUserInterfaceItem>)item
			defaultValidation:(BOOL)defaultValidation
{
	if (item.action == @selector(copy:)) {
		return YES;
	} else {
		return defaultValidation;
	}
}

- (BOOL)webView:(WebView *)webView doCommandBySelector:(SEL)selector
{
	if (selector == @selector(copy:)) {
		[self callJavaScriptFunction:@"copy" withArguments:@[] completionHandler:nil];
		return YES;
	} else {
		return NO;
	}
}
*/

@end
