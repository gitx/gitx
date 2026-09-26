//
//  PBGitBinaryVersionTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitBinary.h"

@interface PBGitBinary (VersionTesting)
+ (NSString *)extractGitVersion:(NSString *)versionString;
@end

@interface PBGitBinaryVersionTests : XCTestCase
@end

@implementation PBGitBinaryVersionTests

- (void)testTheGitInUseReportsItsVersion
{
	NSString *path = [PBGitBinary path];
	XCTAssertNotNil(path, @"no git was found, so nothing below means anything");

	NSTask *task = [[NSTask alloc] init];
	task.executableURL = [NSURL fileURLWithPath:path];
	task.arguments = @[ @"--version" ];
	NSPipe *pipe = [NSPipe pipe];
	task.standardOutput = pipe;
	XCTAssertTrue([task launchAndReturnError:NULL]);
	NSData *output = [pipe.fileHandleForReading readDataToEndOfFile];
	[task waitUntilExit];

	NSString *expected = [PBGitBinary extractGitVersion:[[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding]];

	XCTAssertNotNil([PBGitBinary version], @"every check against a minimum fails when the version is unknown");
	XCTAssertEqualObjects([PBGitBinary version], expected, @"the version has to be that of the git actually in use");
}

- (void)testAVersionMeetsTheMinimumItEquals
{
	XCTAssertTrue([PBGitBinary version:@"2.10" isAtLeast:@"2.10"]);
	XCTAssertTrue([PBGitBinary version:@"2.10.0" isAtLeast:@"2.10"]);
}

- (void)testEachPartIsComparedAsANumberNotAsText
{
	XCTAssertTrue([PBGitBinary version:@"2.10.0" isAtLeast:@"2.9"], @"10 is more than 9");
	XCTAssertFalse([PBGitBinary version:@"2.9.5" isAtLeast:@"2.10"], @"9 is less than 10");
}

- (void)testTheWorktreeBoundariesFallWhereGitDrewThem
{
	XCTAssertFalse([PBGitBinary version:@"2.4.6" isAtLeast:@PBGitWorktreePruneVersion]);
	XCTAssertTrue([PBGitBinary version:@"2.5.0" isAtLeast:@PBGitWorktreePruneVersion]);

	XCTAssertFalse([PBGitBinary version:@"2.9.5" isAtLeast:@PBGitWorktreeLockVersion]);
	XCTAssertTrue([PBGitBinary version:@"2.10.0" isAtLeast:@PBGitWorktreeLockVersion]);

	XCTAssertFalse([PBGitBinary version:@"2.30.9" isAtLeast:@PBGitWorktreeStateVersion]);
	XCTAssertTrue([PBGitBinary version:@"2.31.0" isAtLeast:@PBGitWorktreeStateVersion]);
}

- (void)testAppleGitIsReadByItsVersionNumber
{
	NSString *version = [PBGitBinary extractGitVersion:@"git version 2.50.1 (Apple Git-155)"];

	XCTAssertEqualObjects(version, @"2.50.1");
	XCTAssertTrue([PBGitBinary version:version isAtLeast:@PBGitWorktreeStateVersion]);
}

- (void)testAnUnknownVersionMeetsNoMinimum
{
	XCTAssertFalse([PBGitBinary version:nil isAtLeast:@"1.0"], @"a git whose version could not be read cannot be trusted with anything newer");
}

- (void)testTheExplanationNamesTheVersionNeededAndTheOneFound
{
	NSString *explanation = [PBGitBinary explanationForVersion:@"2.9.5" belowRequired:@"2.10"];

	XCTAssertTrue([explanation containsString:@"2.10"], @"%@", explanation);
	XCTAssertTrue([explanation containsString:@"2.9.5"], @"%@", explanation);
}

- (void)testTheExplanationStillReadsWhenNoVersionWasFound
{
	NSString *explanation = [PBGitBinary explanationForVersion:nil belowRequired:@"2.10"];

	XCTAssertTrue([explanation containsString:@"2.10"], @"%@", explanation);
	XCTAssertFalse([explanation containsString:@"(null)"], @"%@", explanation);
}

@end
