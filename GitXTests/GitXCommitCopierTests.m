//
//  GitXCommitCopierTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "GitXCommitCopier.h"
#import "PBGitCommit.h"

// A commit that cannot produce a patch, which is what the copier is handed
// whenever the format-patch task fails for the selected commit.
@interface PBPatchlessCommit : PBGitCommit
@end

@implementation PBPatchlessCommit

- (NSString *)patch
{
	return nil;
}

@end

@interface GitXCommitCopierTests : XCTestCase
@end

@implementation GitXCommitCopierTests

- (void)testCopiesTheCommitsWhosePatchIsMissingWithoutRaising
{
	PBPatchlessCommit *commit = [[PBPatchlessCommit alloc] init];

	XCTAssertNoThrow([GitXCommitCopier toPatch:@[ commit ]]);
}

@end
