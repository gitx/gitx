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

@interface PBWebCommitController : PBWebController {
	IBOutlet id<PBRefContextDelegate> contextMenuDelegate;
	
	NSString* currentSha;
	NSString* diff;
}

- (void) changeContentTo: (PBGitCommit *) content;
- (void) sendKey: (NSString*) key;
- (NSString *)parseHeader:(NSString *)txt withRefs:(NSString *)badges;
- (NSMutableDictionary *)parseStats:(NSString *)txt;
- (NSString *) arbitraryHashForString:(NSString*)concat;
- (void) openFileMerge:(NSString*)file sha:(NSString *)sha sha2:(NSString *)sha2;

@property (readonly) NSString* diff;
@end
