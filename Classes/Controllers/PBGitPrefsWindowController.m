//
//  PBGitPrefsWindowController.m
//  GitX
//

#import "PBGitPrefsWindowController.h"

#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#import "PBGitRepository.h"

typedef NS_ENUM(NSInteger, PBGitPrefsRowType) {
	PBGitPrefsRowTypeString,
	PBGitPrefsRowTypeBool,
	PBGitPrefsRowTypeAutocrlf,
};

@interface PBGitPrefsRow : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) PBGitPrefsRowType type;
@property (nonatomic, weak) NSControl *localControl;
@property (nonatomic, weak) NSControl *globalControl;
@end

@implementation PBGitPrefsRow
@end

@interface PBGitPrefsWindowController ()
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *loadedLocalConfig;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *loadedGlobalConfig;
@end

@implementation PBGitPrefsWindowController

#pragma mark -
#pragma mark PBGitPrefsWindowController

// +showPrefsForRepository: hands back no reference for the caller to hold onto (matching
// +[PBDiffWindowController showDiff:]'s style), so this class keeps itself alive here for as
// long as its window is open, releasing itself once the window closes.
static NSMutableArray<PBGitPrefsWindowController *> *_openPrefsWindowControllers;

+ (void)showPrefsForRepository:(PBGitRepository *)repository
{
	if (!_openPrefsWindowControllers) {
		_openPrefsWindowControllers = [NSMutableArray array];
	}

	PBGitPrefsWindowController *controller = [[self alloc] initWithWindowNibName:@"PBGitPrefsWindowController"];
	controller.repository = repository;
	[_openPrefsWindowControllers addObject:controller];

	[[NSNotificationCenter defaultCenter] addObserverForName:NSWindowWillCloseNotification
													   object:controller.window
														queue:nil
												   usingBlock:^(NSNotification *note) {
													   [_openPrefsWindowControllers removeObject:controller];
												   }];

	[controller showWindow:self];
}

- (IBAction)showWindow:(id)sender
{
	(void)[self window]; // force the nib (and our outlets) to load before -loadValues runs
	[self loadValues];
	[super showWindow:sender];
}

#pragma mark DBPrefsWindowController overrides

static const NSUInteger kMaxProjectNameLength = 25;

- (void)setupToolbar
{
	NSString *projectName = self.repository.projectName;
	if (projectName.length > kMaxProjectNameLength) {
		// Expanded to whole composed characters so the cut never lands inside one.
		NSRange range = [projectName rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, kMaxProjectNameLength)];
		projectName = [[projectName substringWithRange:range] stringByAppendingString:@"…"];
	}

	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForContentType:UTTypePlainText];

	NSString *repoLabel = [NSString stringWithFormat:NSLocalizedString(@"%@ Prefs.", @"Git Preferences: repository-scoped pane label"), projectName];
	[self addView:self.repositoryPrefsView label:repoLabel image:icon];
	[self addView:self.globalPrefsView label:NSLocalizedString(@"Global Prefs.", @"Git Preferences: global pane label") image:icon];
}

#pragma mark Row list

- (NSArray<PBGitPrefsRow *> *)rows
{
	PBGitPrefsRow *(^makeRow)(NSString *, PBGitPrefsRowType, NSControl *, NSControl *) =
		^PBGitPrefsRow *(NSString *key, PBGitPrefsRowType type, NSControl *local, NSControl *global) {
			PBGitPrefsRow *row = [PBGitPrefsRow new];
			row.key = key;
			row.type = type;
			row.localControl = local;
			row.globalControl = global;
			return row;
		};

	return @[
		makeRow(@"user.name", PBGitPrefsRowTypeString, self.localUserNameField, self.globalUserNameField),
		makeRow(@"user.email", PBGitPrefsRowTypeString, self.localUserEmailField, self.globalUserEmailField),
		makeRow(@"core.editor", PBGitPrefsRowTypeString, self.localCoreEditorField, self.globalCoreEditorField),
		makeRow(@"core.autocrlf", PBGitPrefsRowTypeAutocrlf, self.localAutocrlfPopUp, self.globalAutocrlfPopUp),
		makeRow(@"merge.summary", PBGitPrefsRowTypeBool, self.localMergeSummaryCheckbox, self.globalMergeSummaryCheckbox),
		makeRow(@"merge.verbosity", PBGitPrefsRowTypeString, self.localMergeVerbosityField, self.globalMergeVerbosityField),
		makeRow(@"merge.diffstat", PBGitPrefsRowTypeBool, self.localMergeDiffstatCheckbox, self.globalMergeDiffstatCheckbox),
		makeRow(@"merge.tool", PBGitPrefsRowTypeString, self.localMergeToolField, self.globalMergeToolField),
		makeRow(@"diff.tool", PBGitPrefsRowTypeString, self.localDiffToolField, self.globalDiffToolField),
		makeRow(@"gui.diffopts", PBGitPrefsRowTypeString, self.localDiffOptsField, self.globalDiffOptsField),
		makeRow(@"pull.rebase", PBGitPrefsRowTypeBool, self.localPullRebaseCheckbox, self.globalPullRebaseCheckbox),
		makeRow(@"fetch.prune", PBGitPrefsRowTypeBool, self.localFetchPruneCheckbox, self.globalFetchPruneCheckbox),
		makeRow(@"init.defaultBranch", PBGitPrefsRowTypeString, self.localDefaultBranchField, self.globalDefaultBranchField),
		makeRow(@"commit.gpgsign", PBGitPrefsRowTypeBool, self.localGpgSignCheckbox, self.globalGpgSignCheckbox),
		makeRow(@"user.signingkey", PBGitPrefsRowTypeString, self.localSigningKeyField, self.globalSigningKeyField),
	];
}

#pragma mark Loading

- (void)loadValues
{
	[self setErrorText:@""];

	NSError *error = nil;
	self.loadedLocalConfig = [self.repository gitConfigDictionaryForScope:PBGitConfigScopeLocal error:&error];
	if (!self.loadedLocalConfig) {
		[self setErrorText:error.localizedDescription ?: @""];
		return;
	}

	self.loadedGlobalConfig = [self.repository gitConfigDictionaryForScope:PBGitConfigScopeGlobal error:&error];
	if (!self.loadedGlobalConfig) {
		[self setErrorText:error.localizedDescription ?: @""];
		return;
	}

	for (PBGitPrefsRow *row in self.rows) {
		[self setControl:row.localControl toValue:self.loadedLocalConfig[row.key] type:row.type];
		[self setControl:row.globalControl toValue:self.loadedGlobalConfig[row.key] type:row.type];
	}
}

- (void)setControl:(NSControl *)control toValue:(NSString *)value type:(PBGitPrefsRowType)type
{
	switch (type) {
		case PBGitPrefsRowTypeString: {
			NSTextField *field = (NSTextField *)control;
			field.stringValue = value ?: @"";
			break;
		}
		case PBGitPrefsRowTypeBool: {
			NSButton *checkbox = (NSButton *)control;
			if (value == nil) {
				checkbox.state = NSControlStateValueMixed;
			} else {
				checkbox.state = [self boolValueForConfigString:value] ? NSControlStateValueOn : NSControlStateValueOff;
			}
			break;
		}
		case PBGitPrefsRowTypeAutocrlf: {
			NSPopUpButton *popUp = (NSPopUpButton *)control;
			NSString *title = value.length ? value : @"(not set)";
			if (![popUp itemWithTitle:title]) title = @"(not set)";
			[popUp selectItemWithTitle:title];
			break;
		}
	}
}

// git treats a bare "key" record (no "=value") from `git config --null --list` as boolean true.
- (BOOL)boolValueForConfigString:(NSString *)value
{
	if (value.length == 0) return YES;
	return [value caseInsensitiveCompare:@"true"] == NSOrderedSame || [value isEqualToString:@"1"] || [value caseInsensitiveCompare:@"yes"] == NSOrderedSame;
}

#pragma mark Saving

- (IBAction)save:(id)sender
{
	[self setErrorText:@""];

	for (PBGitPrefsRow *row in self.rows) {
		NSError *error = nil;
		if (![self saveGlobalValueForRow:row error:&error]) {
			[self setErrorText:error.localizedDescription ?: @""];
			return;
		}
		if (![self saveLocalValueForRow:row error:&error]) {
			[self setErrorText:error.localizedDescription ?: @""];
			return;
		}
	}

	[self close];
}

- (void)setErrorText:(NSString *)text
{
	[self.repositoryErrorMessage setStringValue:text];
	[self.globalErrorMessage setStringValue:text];
}

- (BOOL)saveGlobalValueForRow:(PBGitPrefsRow *)row error:(NSError **)error
{
	NSString *newValue = [self stringValueForControl:row.globalControl type:row.type];
	if ([self stringValue:newValue isEqualToConfigValue:self.loadedGlobalConfig[row.key]]) return YES;

	return [self.repository setGitConfigValue:newValue forKey:row.key scope:PBGitConfigScopeGlobal error:error];
}

- (BOOL)saveLocalValueForRow:(PBGitPrefsRow *)row error:(NSError **)error
{
	NSString *newValue = [self stringValueForControl:row.localControl type:row.type];
	if ([self stringValue:newValue isEqualToConfigValue:self.loadedLocalConfig[row.key]]) return YES;

	// git-gui's save_config: when the new local value equals the (originally loaded) global value,
	// unset the local override instead of writing a redundant duplicate, so the repository falls
	// back to the global value.
	NSString *effectiveNewValue = [self stringValue:newValue isEqualToConfigValue:self.loadedGlobalConfig[row.key]] ? nil : newValue;

	return [self.repository setGitConfigValue:effectiveNewValue forKey:row.key scope:PBGitConfigScopeLocal error:error];
}

- (NSString *)stringValueForControl:(NSControl *)control type:(PBGitPrefsRowType)type
{
	switch (type) {
		case PBGitPrefsRowTypeString: {
			NSTextField *field = (NSTextField *)control;
			return field.stringValue;
		}
		case PBGitPrefsRowTypeBool: {
			NSButton *checkbox = (NSButton *)control;
			if (checkbox.state == NSControlStateValueMixed) return nil;
			return (checkbox.state == NSControlStateValueOn) ? @"true" : @"false";
		}
		case PBGitPrefsRowTypeAutocrlf: {
			NSPopUpButton *popUp = (NSPopUpButton *)control;
			NSString *title = popUp.selectedItem.title;
			return [title isEqualToString:@"(not set)"] ? nil : title;
		}
	}
	return nil;
}

- (BOOL)stringValue:(NSString *)newValue isEqualToConfigValue:(NSString *)oldValue
{
	NSString *normalizedNew = newValue.length ? newValue : nil;
	NSString *normalizedOld = oldValue.length ? oldValue : nil;
	if (normalizedNew == nil || normalizedOld == nil) return (normalizedNew == normalizedOld);
	return [normalizedNew isEqualToString:normalizedOld];
}

#pragma mark IBActions

- (IBAction)cancelOperation:(id)sender
{
	[self close];
}

@end
