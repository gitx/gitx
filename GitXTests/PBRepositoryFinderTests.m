//
//  PBRepositoryFinderTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBRepositoryFinder.h"

// The finder hands libgit2 a git_buf and turns the bytes it writes back into a
// path, so these need a repository that actually exists on disk rather than the
// stubs the other suites here use.
@interface PBRepositoryFinderTests : XCTestCase
@property (nonatomic, strong) NSURL *workDir;
@end

@implementation PBRepositoryFinderTests

- (void)setUp
{
	[super setUp];

	self.workDir = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
		URLByAppendingPathComponent:[NSString stringWithFormat:@"GitXFinder-%@", NSUUID.UUID.UUIDString]
						isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:self.workDir
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];

	NSTask *task = [[NSTask alloc] init];
	task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/git"];
	task.arguments = @[@"init", @"--quiet", self.workDir.path];
	task.environment = @{@"PATH" : @"/usr/bin:/bin",
						 @"GIT_CONFIG_GLOBAL" : @"/dev/null",
						 @"GIT_CONFIG_SYSTEM" : @"/dev/null"};
	task.standardOutput = NSFileHandle.fileHandleWithNullDevice;
	task.standardError = NSFileHandle.fileHandleWithNullDevice;

	NSError *error = nil;
	if (![task launchAndReturnError:&error]) {
		XCTFail(@"git init did not start: %@", error);
		return;
	}

	[task waitUntilExit];
	XCTAssertEqual(task.terminationStatus, 0, @"git init failed, so there is no repository to find");
}

- (void)tearDown
{
	[NSFileManager.defaultManager removeItemAtURL:self.workDir error:NULL];
	self.workDir = nil;

	[super tearDown];
}

- (NSString *)resolvedGitDirPath
{
	// The temporary directory is itself a symlink on macOS, so compare what both
	// sides resolve to rather than the paths as spelled.
	return [self.workDir URLByAppendingPathComponent:@".git" isDirectory:YES].URLByResolvingSymlinksInPath.path;
}

- (void)testFindsTheGitDirectoryOfARepositoryRoot
{
	NSURL *found = [PBRepositoryFinder gitDirForURL:self.workDir];

	XCTAssertNotNil(found);
	XCTAssertEqualObjects(found.URLByResolvingSymlinksInPath.path, self.resolvedGitDirPath);
}

- (void)testFindsTheGitDirectoryFromANestedSubdirectory
{
	NSURL *nested = [self.workDir URLByAppendingPathComponent:@"one/two/three" isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:nested
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];

	NSURL *found = [PBRepositoryFinder gitDirForURL:nested];

	XCTAssertNotNil(found);
	XCTAssertEqualObjects(found.URLByResolvingSymlinksInPath.path, self.resolvedGitDirPath);
}

- (void)testReturnsNilForADirectoryOutsideAnyRepository
{
	NSURL *outside = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
		URLByAppendingPathComponent:[NSString stringWithFormat:@"GitXPlain-%@", NSUUID.UUID.UUIDString]
						isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:outside
						   withIntermediateDirectories:YES
											attributes:nil
												 error:NULL];

	XCTAssertNil([PBRepositoryFinder gitDirForURL:outside]);

	[NSFileManager.defaultManager removeItemAtURL:outside error:NULL];
}

- (void)testReturnsNilForANonFileURL
{
	XCTAssertNil([PBRepositoryFinder gitDirForURL:[NSURL URLWithString:@"https://example.com/repo.git"]]);
}

@end
