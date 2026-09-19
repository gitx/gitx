//
//  PBPrefsWindowController.m
//  GitX
//
//  Created by Christian Jacobsen on 02/10/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBPrefsWindowController.h"
#import "PBGitRepository.h"
#import "PBGitDefaults.h"
#import "PBTerminalUtil.h"
#import "PBGitCommitDateFormatter.h"

#define kPreferenceViewIdentifier @"PBGitXPreferenceViewIdentifier"

@implementation PBPrefsWindowController

#pragma mark DBPrefsWindowController overrides

- (void)windowDidLoad
{
	[super windowDidLoad];

	[self populateTerminalHandlers];
	[self updateCommitDateSample];
}

- (void)setupToolbar
{
	// GENERAL
	[self addView:generalPrefsView label:@"General" image:[NSImage imageNamed:NSImageNameApplicationIcon]];
	// INTERGRATION
	[self addView:integrationPrefsView label:@"Integration" image:[NSImage imageNamed:NSImageNameNetwork]];
	// UPDATES
	[self addView:updatesPrefsView label:@"Updates"];
}

- (void)displayViewForIdentifier:(NSString *)identifier animate:(BOOL)animate
{
	[super displayViewForIdentifier:identifier animate:animate];

	[[NSUserDefaults standardUserDefaults] setObject:identifier forKey:kPreferenceViewIdentifier];
}

- (NSString *)defaultViewIdentifier
{
	NSString *identifier = [[NSUserDefaults standardUserDefaults] objectForKey:kPreferenceViewIdentifier];
	if (identifier)
		return identifier;

	return [super defaultViewIdentifier];
}

#pragma mark -
#pragma mark Delegate methods

- (IBAction)checkGitValidity:sender
{
	// FIXME: This does not work reliably, probably due to: http://www.cocoabuilder.com/archive/message/cocoa/2008/9/10/217850
	//[badGitPathIcon setHidden:[PBGitRepository validateGit:[[NSValueTransformer valueTransformerForName:@"PBNSURLPathUserDefaultsTransfomer"] reverseTransformedValue:[gitPathController URL]]]];
}

- (IBAction)resetGitPath:sender
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"gitExecutable"];
}

- (void)pathCell:(NSPathCell *)pathCell willDisplayOpenPanel:(NSOpenPanel *)openPanel
{
	[openPanel setCanChooseDirectories:NO];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setTreatsFilePackagesAsDirectories:YES];
	[openPanel setAccessoryView:gitPathOpenAccessory];
	[openPanel setResolvesAliases:NO];
	//[[openPanel _navView] setShowsHiddenFiles:YES];

	gitPathOpenPanel = openPanel;
}

- (IBAction)resetAllDialogWarnings:(id)sender
{
	[PBGitDefaults resetAllDialogWarnings];
}

#pragma mark -
#pragma mark Terminal application

- (void)populateTerminalHandlers
{
	terminalHandlerPopup.menu.autoenablesItems = NO;
	[terminalHandlerPopup removeAllItems];

	for (NSString *handler in [PBTerminalUtil supportedHandlers]) {
		NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[PBTerminalUtil nameForHandler:handler]
													  action:NULL
											   keyEquivalent:@""];
		item.representedObject = handler;

		if (![PBTerminalUtil isHandlerInstalled:handler]) {
			item.enabled = NO;
			item.toolTip = [NSString stringWithFormat:@"%@ is not installed", item.title];
		}

		[terminalHandlerPopup.menu addItem:item];
	}

	NSString *handler = [PBTerminalUtil handlerForPreference:[PBGitDefaults terminalHandler]];
	NSInteger index = [terminalHandlerPopup indexOfItemWithRepresentedObject:handler];
	if (index != -1) {
		[terminalHandlerPopup selectItemAtIndex:index];
	}
}

- (IBAction)changeTerminalHandler:(id)sender
{
	NSString *handler = [[sender selectedItem] representedObject];
	if (!handler) {
		return;
	}

	[PBGitDefaults setTerminalHandler:handler];
}

#pragma mark -
#pragma mark Commit date format

// The popup and the field are read rather than the preferences they write, so
// the sample shows what was just picked whichever of them the change came from.
- (void)updateCommitDateSample
{
	PBCommitDateFormatSetting setting = commitDateFormatPopup.selectedTag;
	NSString *customFormat = commitDateCustomFormatField.stringValue;

	commitDateCustomFormatField.enabled = (setting == PBCommitDateFormatCustom);

	NSDateFormatter *formatter = [PBGitCommitDateFormatter dateFormatterForSetting:setting customFormat:customFormat];
	NSString *sample = [formatter stringFromDate:[NSDate date]];

	// A pattern can be well formed and still render to nothing, so the sample
	// says the column would be empty instead of going blank itself.
	commitDateSampleField.stringValue = sample.length ? sample : NSLocalizedString(@"(nothing)", @"Preferences: what an empty commit date pattern shows");
}

- (IBAction)changeCommitDateFormat:(id)sender
{
	[self updateCommitDateSample];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
	if (notification.object == commitDateCustomFormatField)
		[self updateCommitDateSample];
}

#pragma mark -
#pragma mark Git Path open panel actions

- (IBAction)showHideAllFiles:sender
{
	/* FIXME: This uses undocumented OpenPanel features to show hidden files! */
	NSNumber *showHidden = [NSNumber numberWithBool:[sender state] == NSControlStateValueOn];
	[[gitPathOpenPanel valueForKey:@"_navView"] setValue:showHidden forKey:@"showsHiddenFiles"];
}

@end
