//
//  PBGitPrefsWindowController.h
//  GitX
//

#import <Cocoa/Cocoa.h>
#import "DBPrefsWindowController.h"

@class PBGitRepository;

@interface PBGitPrefsWindowController : DBPrefsWindowController

+ (void)showPrefsForRepository:(PBGitRepository *)repository;

@property (nonatomic, strong) PBGitRepository *repository;

@property (readwrite, weak) IBOutlet NSView *repositoryPrefsView;
@property (readwrite, weak) IBOutlet NSView *globalPrefsView;

@property (readwrite, weak) IBOutlet NSTextField *repositoryErrorMessage;
@property (readwrite, weak) IBOutlet NSTextField *globalErrorMessage;

@property (readwrite, weak) IBOutlet NSTextField *localUserNameField;
@property (readwrite, weak) IBOutlet NSTextField *globalUserNameField;
@property (readwrite, weak) IBOutlet NSTextField *localUserEmailField;
@property (readwrite, weak) IBOutlet NSTextField *globalUserEmailField;
@property (readwrite, weak) IBOutlet NSTextField *localCoreEditorField;
@property (readwrite, weak) IBOutlet NSTextField *globalCoreEditorField;
@property (readwrite, weak) IBOutlet NSPopUpButton *localAutocrlfPopUp;
@property (readwrite, weak) IBOutlet NSPopUpButton *globalAutocrlfPopUp;
@property (readwrite, weak) IBOutlet NSButton *localMergeSummaryCheckbox;
@property (readwrite, weak) IBOutlet NSButton *globalMergeSummaryCheckbox;
@property (readwrite, weak) IBOutlet NSTextField *localMergeVerbosityField;
@property (readwrite, weak) IBOutlet NSTextField *globalMergeVerbosityField;
@property (readwrite, weak) IBOutlet NSButton *localMergeDiffstatCheckbox;
@property (readwrite, weak) IBOutlet NSButton *globalMergeDiffstatCheckbox;
@property (readwrite, weak) IBOutlet NSTextField *localMergeToolField;
@property (readwrite, weak) IBOutlet NSTextField *globalMergeToolField;
@property (readwrite, weak) IBOutlet NSTextField *localDiffToolField;
@property (readwrite, weak) IBOutlet NSTextField *globalDiffToolField;
@property (readwrite, weak) IBOutlet NSTextField *localDiffOptsField;
@property (readwrite, weak) IBOutlet NSTextField *globalDiffOptsField;
@property (readwrite, weak) IBOutlet NSButton *localPullRebaseCheckbox;
@property (readwrite, weak) IBOutlet NSButton *globalPullRebaseCheckbox;
@property (readwrite, weak) IBOutlet NSButton *localFetchPruneCheckbox;
@property (readwrite, weak) IBOutlet NSButton *globalFetchPruneCheckbox;
@property (readwrite, weak) IBOutlet NSTextField *localDefaultBranchField;
@property (readwrite, weak) IBOutlet NSTextField *globalDefaultBranchField;
@property (readwrite, weak) IBOutlet NSButton *localGpgSignCheckbox;
@property (readwrite, weak) IBOutlet NSButton *globalGpgSignCheckbox;
@property (readwrite, weak) IBOutlet NSTextField *localSigningKeyField;
@property (readwrite, weak) IBOutlet NSTextField *globalSigningKeyField;

- (IBAction)save:(id)sender;
- (IBAction)cancelOperation:(id)sender;

@end
