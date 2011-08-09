//
//  PBDetailController.m
//  GitX
//
//  Created by Pieter de Bie on 16-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitWindowController.h"
#import "PBGitHistoryController.h"
#import "PBGitCommitController.h"
#import "PBGitDefaults.h"
#import "Terminal.h"
#import "PBCloneRepsitoryToSheet.h"
#import "PBCommitHookFailedSheet.h"
#import "PBGitXMessageSheet.h"
#import "PBGitSidebarController.h"

@implementation PBGitWindowController


@synthesize repository;

- (id)initWithRepository:(PBGitRepository*)theRepository displayDefault:(BOOL)displayDefault
{
	if (!(self = [self initWithWindowNibName:@"RepositoryWindow"]))
		return nil;
    
	self.repository = theRepository;
    
	return self;
}

- (void)windowWillClose:(NSNotification *)notification
{
	//DLog(@"Window will close!");
    
	if (sidebarController)
		[sidebarController closeView];
    
	if (contentController)
		[contentController removeObserver:self forKeyPath:@"status"];
}
- (NSApplicationPresentationOptions)window:(NSWindow *)window willUseFullScreenPresentationOptions:(NSApplicationPresentationOptions)proposedOptions
{
    return NSApplicationPresentationAutoHideToolbar | NSApplicationPresentationFullScreen | NSApplicationPresentationAutoHideMenuBar | NSApplicationPresentationAutoHideDock;
}
- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(showCommitView:)) {
		[menuItem setState:(contentController == sidebarController.commitViewController) ? YES : NO];
		return ![repository isBareRepository];
	} else if ([menuItem action] == @selector(showHistoryView:)) {
		[menuItem setState:(contentController != sidebarController.commitViewController) ? YES : NO];
		return ![repository isBareRepository];
	} else if ([menuItem action] == @selector(commit:)){
        return [contentController isKindOfClass:[PBGitCommitController class]]; 
    }
	return YES;
}
- (IBAction) commit:(id) sender
{
    [(PBGitCommitController *)contentController commit:sender];
}

- (void) awakeFromNib
{
	[[self window] setDelegate:self];
	[[self window] setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
	[[self window] setContentBorderThickness:31.0f forEdge:NSMinYEdge];
    
	sidebarController = [[PBGitSidebarController alloc] initWithRepository:repository superController:self];
	[[sidebarController view] setFrame:[sourceSplitView bounds]];
	[sourceSplitView addSubview:[sidebarController view]];
	[sourceListControlsView addSubview:sidebarController.sourceListControlsView];
    
	[[statusField cell] setBackgroundStyle:NSBackgroundStyleRaised];
	[progressIndicator setUsesThreadedAnimation:YES];
    
	NSImage *finderImage = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kFinderIcon)];
	[finderItem setImage:finderImage];
    
	NSImage *terminalImage = [[NSWorkspace sharedWorkspace] iconForFile:@"/Applications/Utilities/Terminal.app/"];
	[terminalItem setImage:terminalImage];
    
	[self showWindow:nil];
    [self initChangeLayout];
}

- (void) removeAllContentSubViews
{
	if ([contentSplitView subviews])
		while ([[contentSplitView subviews] count] > 0)
			[[[contentSplitView subviews] lastObject] removeFromSuperviewWithoutNeedingDisplay];
}

- (void) changeContentController:(PBViewController *)controller
{
	if (!controller || (contentController == controller))
		return;
    
	if (contentController)
		[contentController removeObserver:self forKeyPath:@"status"];
    
	[self removeAllContentSubViews];
    
	contentController = controller;
	
	[[contentController view] setFrame:[contentSplitView bounds]];
	[contentSplitView addSubview:[contentController view]];
    
	[self setNextResponder: contentController];
	[[self window] makeFirstResponder:[contentController firstResponder]];
	[contentController updateView];
	[contentController addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionInitial context:@"statusChange"];
}

- (void) showCommitView:(id)sender
{
	[sidebarController selectStage];
}

- (void) showHistoryView:(id)sender
{
	[sidebarController selectCurrentBranch];
}

- (void)showCommitHookFailedSheet:(NSString *)messageText infoText:(NSString *)infoText commitController:(PBGitCommitController *)controller
{
	[PBCommitHookFailedSheet beginMessageSheetForWindow:[self window] withMessageText:messageText infoText:infoText commitController:controller];
}

- (void)showMessageSheet:(NSString *)messageText infoText:(NSString *)infoText
{
	[PBGitXMessageSheet beginMessageSheetForWindow:[self window] withMessageText:messageText infoText:infoText];
}

- (void)showErrorSheet:(NSError *)error
{
	if ([[error domain] isEqualToString:PBGitRepositoryErrorDomain])
		[PBGitXMessageSheet beginMessageSheetForWindow:[self window] withError:error];
	else
		[[NSAlert alertWithError:error] beginSheetModalForWindow:[self window] modalDelegate:self didEndSelector:nil contextInfo:nil];
}


- (void)windowDidBecomeKey:(NSNotification *)notification
{
	if ([PBGitDefaults refreshAutomatically]) {
		[contentController refresh:nil];
	}
	
	if ([PBGitDefaults isUseITerm2]) {
		[terminalItem setImage:[[NSWorkspace sharedWorkspace] iconForFile:[[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.googlecode.iterm2"]]];
		[terminalItem setLabel:@"iTerm"];
	}
	else {
		[terminalItem setImage:[[NSWorkspace sharedWorkspace] iconForFile:@"/Applications/Utilities/Terminal.app/"]];
		[terminalItem setLabel:@"Terminal"];
	}
}

- (void)showErrorSheetTitle:(NSString *)title message:(NSString *)message arguments:(NSArray *)arguments output:(NSString *)output
{
	NSString *command = [arguments componentsJoinedByString:@" "];
	NSString *reason = [NSString stringWithFormat:@"%@\n\ncommand: git %@\n%@", message, command, output];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  title, NSLocalizedDescriptionKey,
							  reason, NSLocalizedRecoverySuggestionErrorKey,
							  nil];
	NSError *error = [NSError errorWithDomain:PBGitRepositoryErrorDomain code:0 userInfo:userInfo];
	[self showErrorSheet:error];
}

- (IBAction) revealInFinder:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:[repository workingDirectory]];
}

- (IBAction) openInTerminal:(id)sender
{
	NSString *workingDirectory = [[repository workingDirectory] stringByAppendingString:@"/"];
	
	if ([PBGitDefaults isUseITerm2]) {
		NSStringEncoding encoding;		 
		NSString *resourcePath = [[[NSBundle bundleForClass:[self class]] resourcePath] stringByAppendingPathComponent:@"Start_iTerm2.applescript"];
		NSString *scriptSource = [NSString stringWithContentsOfFile:resourcePath usedEncoding:&encoding error:nil];
		NSString *iTerm2StartScript = [scriptSource stringByReplacingOccurrencesOfString:@"%%workDir%%" withString:workingDirectory];
		
		NSAppleScript *scriptObject = [[NSAppleScript alloc] initWithSource:iTerm2StartScript];
		[scriptObject executeAndReturnError:nil];
	}
	else {
		TerminalApplication *term = [SBApplication applicationWithBundleIdentifier:@"com.apple.Terminal"];	
		NSString *cmd = [NSString stringWithFormat: @"cd \"%@\"; clear; echo '# Opened by GitX:'; git status", workingDirectory];	
		[term doScript: cmd in: nil];
		[NSThread sleepForTimeInterval: 0.1];
		[term activate];
	}
	
}

- (IBAction) cloneTo:(id)sender
{
	[PBCloneRepsitoryToSheet beginCloneRepsitoryToSheetForRepository:repository];
}

- (IBAction) refresh:(id)sender
{
    [sidebarController.historyViewController refresh: self];
    [sidebarController.commitViewController refresh: self];
}

- (void) updateStatus
{
	NSString *status = contentController.status;
	BOOL isBusy = contentController.isBusy;
    
	if (!status) {
		status = @"";
		isBusy = NO;
	}
    
	[statusField setStringValue:status];
    
	if (isBusy) {
		[progressIndicator startAnimation:self];
		[progressIndicator setHidden:NO];
	}
	else {
		[progressIndicator stopAnimation:self];
		[progressIndicator setHidden:YES];
	}
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([(NSString *)context isEqualToString:@"statusChange"]) {
		[self updateStatus];
		return;
	}
    
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void) selectCommitForSha:(NSString *)sha
{
	if (contentController != sidebarController.historyViewController)
		[sidebarController selectCurrentBranch];
	[sidebarController.historyViewController selectCommit:sha];
}

- (NSArray *) menuItemsForPaths:(NSArray *)paths
{
	return [sidebarController.historyViewController menuItemsForPaths:paths];
}

- (void)setHistorySearch:(NSString *)searchString mode:(NSInteger)mode
{
	[sidebarController setHistorySearch:searchString mode:mode];
}

#pragma mark - SplitView changeLayout
-(void)initChangeLayout
{
    splitViews=[NSArray arrayWithObjects:mainSplitView,[[sidebarController historyViewController] historySplitView], nil];
    splitViewsSize=[NSMutableArray arrayWithCapacity:[splitViews count]];
    for (int n=0; n<[splitViews count]; n++) {
        NSSplitView *splitView=[splitViews objectAtIndex:n];
        NSView *left=[[splitView subviews] objectAtIndex:0];
        [splitViewsSize addObject:[NSNumber numberWithInt:[left frame].size.width]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(resizeSubviewsHandler:)
                                                     name:NSSplitViewWillResizeSubviewsNotification
                                                   object:splitView
         ];
    }
}

- (IBAction)changeLayout:(id)sender
{
    NSInteger index=[sender selectedSegment];
    NSSplitView *splitView=[splitViews objectAtIndex:index];
    NSView *left=[[splitView subviews] objectAtIndex:0];
    
    CGFloat pos;
    if ([splitView isSubviewCollapsed:left])
        pos=[[splitViewsSize objectAtIndex:index] intValue];
    else
        pos=[splitView minPossiblePositionOfDividerAtIndex:0];

    [splitView setPosition:pos ofDividerAtIndex:0 ];
}

- (void)resizeSubviewsHandler:(NSNotification *)notif
{
    NSSplitView *splitView=[notif object];
    NSInteger index=[splitViews indexOfObject:splitView];
    NSView *left=[[splitView subviews] objectAtIndex:0];

    NSNumber *pos;
    if([splitView isVertical]){
        pos=[NSNumber numberWithInt:[left frame].size.width];
    }else{
        pos=[NSNumber numberWithInt:[left frame].size.height];
    }
        
    [splitViewsSize removeObjectAtIndex:index];
    [splitViewsSize insertObject:pos atIndex:index];
}

#pragma mark -
#pragma mark SplitView Delegates

- (BOOL)splitView:(NSSplitView *)sp canCollapseSubview:(NSView *)subview
{
	return TRUE;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex
{
	NSUInteger index = [[splitView subviews] indexOfObject:subview];
	return index==0;
}

#pragma mark min/max widths while moving the divider

- (CGFloat)splitView:(NSSplitView *)view constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
	if (proposedMin < kGitSplitViewMinWidth)
		return kGitSplitViewMinWidth;
    
	return proposedMin;
}

- (CGFloat)splitView:(NSSplitView *)view constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
	if (dividerIndex == 0)
		return kGitSplitViewMaxWidth;
    
	return proposedMax;
}

#pragma mark constrain sidebar width while resizing the window

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSRect newFrame = [sender frame];
    
	float dividerThickness = [sender dividerThickness];
    
	NSView *sourceView = [[sender subviews] objectAtIndex:0];
	NSRect sourceFrame = [sourceView frame];
	sourceFrame.size.height = newFrame.size.height;
    
	NSView *mainView = [[sender subviews] objectAtIndex:1];
	NSRect mainFrame = [mainView frame];
	mainFrame.origin.x = sourceFrame.size.width + dividerThickness;
	mainFrame.size.width = newFrame.size.width - mainFrame.origin.x;
	mainFrame.size.height = newFrame.size.height;
    
	[sourceView setFrame:sourceFrame];
	[mainView setFrame:mainFrame];
}

@end
