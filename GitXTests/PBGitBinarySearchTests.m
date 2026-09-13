//
//  PBGitBinarySearchTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitBinary.h"

@interface PBGitBinary (SearchTesting)
+ (NSArray *)searchLocations;
@end

@interface PBGitBinarySearchTests : XCTestCase
@end

@implementation PBGitBinarySearchTests

- (void)testTheHomebrewPrefixesAreBothSearched
{
	NSArray *locations = [PBGitBinary searchLocations];

	XCTAssertTrue([locations containsObject:@"/opt/homebrew/bin/git"], @"Homebrew installs there on Apple Silicon");
	XCTAssertTrue([locations containsObject:@"/usr/local/bin/git"], @"and there on Intel");
}

- (void)testAppleGitIsSearchedLastOfAll
{
	NSArray *locations = [PBGitBinary searchLocations];

	XCTAssertEqualObjects(locations.lastObject, @"/usr/bin/git", @"the one that can be a stub asking for an Xcode licence comes last");
}

- (void)testTheSearchLocationsAreNamedInTheErrorTheUserSees
{
	NSString *message = [PBGitBinary notFoundError];

	for (NSString *location in [PBGitBinary searchLocations])
		XCTAssertTrue([message rangeOfString:location].location != NSNotFound, @"%@ is missing from the error", location);
}

@end
