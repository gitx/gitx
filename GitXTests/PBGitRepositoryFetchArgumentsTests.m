//
//  PBGitRepositoryFetchArgumentsTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"
#import "PBGitDefaults.h"

// Exposes the argument builder shared by both fetch entry points, so the
// preference/override matrix can be checked without launching git.
@interface PBGitRepository (FetchArgumentsTesting)
+ (NSArray<NSString *> *)fetchArgumentsForTarget:(NSString *)fetchArg forcePrune:(BOOL)forcePrune;
@end

@interface PBGitRepositoryFetchArgumentsTests : XCTestCase
@end

@implementation PBGitRepositoryFetchArgumentsTests

- (void)setPruneOnFetchSetting:(PBPruneOnFetchSetting)setting
{
	[[NSUserDefaults standardUserDefaults] setInteger:setting forKey:@"PBPruneOnFetch"];
	XCTAssertEqual([PBGitDefaults pruneOnFetch], setting);
}

- (void)tearDown
{
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"PBPruneOnFetch"];
	[super tearDown];
}

// Without an explicit override the preference alone decides, as it has since
// prune-on-fetch was introduced.
- (void)testPreferenceDecidesWhenPruneIsNotForced
{
	[self setPruneOnFetchSetting:PBPruneOnFetchUseGitConfig];
	XCTAssertEqualObjects([PBGitRepository fetchArgumentsForTarget:@"origin" forcePrune:NO], (@[ @"fetch", @"origin" ]));

	[self setPruneOnFetchSetting:PBPruneOnFetchAlways];
	XCTAssertEqualObjects([PBGitRepository fetchArgumentsForTarget:@"origin" forcePrune:NO], (@[ @"fetch", @"--prune", @"origin" ]));

	[self setPruneOnFetchSetting:PBPruneOnFetchNever];
	XCTAssertEqualObjects([PBGitRepository fetchArgumentsForTarget:@"origin" forcePrune:NO], (@[ @"fetch", @"--no-prune", @"origin" ]));
}

// The "Fetch … and Prune" menu items are an explicit user action, so they must
// prune in every preference state - including "Never prune".
- (void)testForcedPruneOverridesEveryPreferenceState
{
	NSArray *expected = @[ @"fetch", @"--prune", @"origin" ];

	[self setPruneOnFetchSetting:PBPruneOnFetchUseGitConfig];
	XCTAssertEqualObjects([PBGitRepository fetchArgumentsForTarget:@"origin" forcePrune:YES], expected);

	[self setPruneOnFetchSetting:PBPruneOnFetchAlways];
	XCTAssertEqualObjects([PBGitRepository fetchArgumentsForTarget:@"origin" forcePrune:YES], expected);

	[self setPruneOnFetchSetting:PBPruneOnFetchNever];
	XCTAssertEqualObjects([PBGitRepository fetchArgumentsForTarget:@"origin" forcePrune:YES], expected);
}

// git rejects flags placed after the remote, so the ordering is load-bearing.
- (void)testFlagPrecedesTheFetchTarget
{
	[self setPruneOnFetchSetting:PBPruneOnFetchNever];
	XCTAssertEqualObjects([PBGitRepository fetchArgumentsForTarget:@"--all" forcePrune:YES], (@[ @"fetch", @"--prune", @"--all" ]));
	XCTAssertEqualObjects([PBGitRepository fetchArgumentsForTarget:@"--all" forcePrune:NO], (@[ @"fetch", @"--no-prune", @"--all" ]));
}

@end
