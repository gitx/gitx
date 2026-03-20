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

- (void)didLoad
{
	// TODO: Implement Index object injection for WKWebView
	// The Index object needs to be exposed to JavaScript through a message handler approach
	// This requires understanding what methods the JavaScript code calls on Index
	// and implementing corresponding message handlers
	// For now, we log this limitation
	NSLog(@"WARNING: Index object injection not yet implemented for WKWebView - commit view functionality may be limited");
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
