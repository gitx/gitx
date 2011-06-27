//
//  PBWebCommitController.h
//
//  Created by David Catmull on 10-06-11.
//

#import <Cocoa/Cocoa.h>
#import "PBWebController.h"

#import "PBRefContextDelegate.h"


@class NSString;
@class PBGitCommit;

// Displays the diff from a commit in the repository.
@interface PBWebCommitController : PBWebController {
	IBOutlet id<PBRefContextDelegate> contextMenuDelegate;
	
	NSString* currentSha;
	NSString* diff;
	BOOL showLongDiffs;
}

- (void) changeContentTo: (PBGitCommit *) content;
- (void) sendKey: (NSString*) key;
- (void) openFileMerge:(NSString*)file sha:(NSString *)sha sha2:(NSString *)sha2;
- (void) showLongDiff;

- (void) didLoad;
// Called when a commit or parent link is clicked.
- (void)selectCommit:(NSString *)sha;
// HTML listing refs (branch name, etc) for the displayed commit.
- (NSString*) refsForCurrentCommit;
// Look up a PBGitRef based on its SHA.
- (PBGitRef*) refFromString:(NSString*)refString;
// Choose which parents should be used for the diff
- (NSArray*) chooseDiffParents:(NSArray*)parents;
// Context menu items to be displayed for a file.
- (NSArray*) menuItemsForPath:(NSString*)path;

@property (readonly) NSString* diff;
@end
