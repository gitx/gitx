//
//  PBGitRepositoryForcePushTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"
#import "PBGitRef.h"
#import "PBTask.h"

@interface PBGitRepositoryForcePushTests : XCTestCase
@property (nonatomic, copy) NSString *sandbox;
@end

@implementation PBGitRepositoryForcePushTests

- (void)setUp
{
	[super setUp];

	self.sandbox = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
	[[NSFileManager defaultManager] createDirectoryAtPath:self.sandbox withIntermediateDirectories:YES attributes:nil error:NULL];
}

- (void)tearDown
{
	[[NSFileManager defaultManager] removeItemAtPath:self.sandbox error:NULL];

	[super tearDown];
}

- (NSError *)pushErrorWithGitOutput:(NSString *)output
{
	NSError *taskError = [NSError errorWithDomain:PBTaskErrorDomain
											 code:PBTaskNonZeroExitCodeError
										 userInfo:@{PBTaskTerminationOutputKey : output}];
	return [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:@{NSUnderlyingErrorKey : taskError}];
}

- (void)testANonFastForwardRejectionIsRecognised
{
	NSError *error = [self pushErrorWithGitOutput:@" ! [rejected]        feature -> feature (non-fast-forward)\n"];

	XCTAssertTrue([PBGitRepository isRejectedPushError:error]);
}

- (void)testAFetchFirstRejectionIsRecognised
{
	NSError *error = [self pushErrorWithGitOutput:@" ! [rejected]        feature -> feature (fetch first)\n"];

	XCTAssertTrue([PBGitRepository isRejectedPushError:error]);
}

- (void)testAStaleLeaseIsNotOfferedAnotherForce
{
	NSError *error = [self pushErrorWithGitOutput:@" ! [rejected]        feature -> feature (stale info)\n"];

	XCTAssertFalse([PBGitRepository isRejectedPushError:error]);
}

- (void)testAnUnrelatedFailureIsNotARejection
{
	NSError *error = [self pushErrorWithGitOutput:@"fatal: Could not read from remote repository.\n"];

	XCTAssertFalse([PBGitRepository isRejectedPushError:error]);
}

- (void)testAnErrorWithoutATaskIsNotARejection
{
	XCTAssertFalse([PBGitRepository isRejectedPushError:[NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil]]);
}

- (BOOL)runGit:(NSArray<NSString *> *)arguments inDirectory:(NSString *)directory
{
	NSTask *task = [[NSTask alloc] init];
	task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/git"];
	task.arguments = arguments;
	task.environment = @{@"GIT_AUTHOR_NAME" : @"t", @"GIT_AUTHOR_EMAIL" : @"t@t", @"GIT_COMMITTER_NAME" : @"t", @"GIT_COMMITTER_EMAIL" : @"t@t", @"PATH" : @"/usr/bin:/bin", @"GIT_CONFIG_GLOBAL" : @"/dev/null", @"GIT_CONFIG_SYSTEM" : @"/dev/null"};
	task.currentDirectoryURL = [NSURL fileURLWithPath:directory];
	task.standardOutput = [NSPipe pipe];
	task.standardError = [NSPipe pipe];
	[task launchAndReturnError:NULL];
	[task waitUntilExit];
	return task.terminationStatus == 0;
}

// A clone whose feature branch was rewritten after it was pushed, so that a
// plain push is rejected; a second clone can then move the remote on.
- (PBGitRepository *)rewrittenCloneOfRemoteAt:(NSString *)remote
{
	NSString *clone = [self.sandbox stringByAppendingPathComponent:@"clone"];
	XCTAssertTrue(([self runGit:@[ @"clone", @"--quiet", remote, clone ] inDirectory:self.sandbox]));
	XCTAssertTrue(([self runGit:@[ @"checkout", @"--quiet", @"-b", @"feature" ] inDirectory:clone]));
	XCTAssertTrue(([self runGit:@[ @"commit", @"--quiet", @"--allow-empty", @"-m", @"first" ] inDirectory:clone]));
	XCTAssertTrue(([self runGit:@[ @"push", @"--quiet", @"--set-upstream", @"origin", @"feature" ] inDirectory:clone]));
	XCTAssertTrue(([self runGit:@[ @"commit", @"--quiet", @"--allow-empty", @"--amend", @"-m", @"amended" ] inDirectory:clone]));

	NSError *error = nil;
	PBGitRepository *repository = [[PBGitRepository alloc] initWithURL:[NSURL fileURLWithPath:clone] error:&error];
	XCTAssertNotNil(repository, @"%@", error);
	return repository;
}

- (NSString *)bareRemoteWithMaster
{
	NSString *seed = [self.sandbox stringByAppendingPathComponent:@"seed"];
	NSString *remote = [self.sandbox stringByAppendingPathComponent:@"remote.git"];
	[[NSFileManager defaultManager] createDirectoryAtPath:seed withIntermediateDirectories:YES attributes:nil error:NULL];
	XCTAssertTrue(([self runGit:@[ @"init", @"--quiet", @"--initial-branch=master" ] inDirectory:seed]));
	XCTAssertTrue(([self runGit:@[ @"commit", @"--quiet", @"--allow-empty", @"-m", @"root" ] inDirectory:seed]));
	XCTAssertTrue(([self runGit:@[ @"clone", @"--quiet", @"--bare", seed, remote ] inDirectory:self.sandbox]));
	return remote;
}

- (void)testARewrittenBranchIsRejectedThenForcedThroughWithTheLease
{
	NSString *remote = [self bareRemoteWithMaster];
	PBGitRepository *repository = [self rewrittenCloneOfRemoteAt:remote];
	PBGitRef *feature = [PBGitRef refFromString:@"refs/heads/feature"];
	NSString *expectedSHA = [repository remoteTrackingSHAForBranch:feature toRemote:nil];
	XCTAssertEqual(expectedSHA.length, 40u);

	NSError *error = nil;
	XCTAssertFalse([repository pushBranch:feature toRemote:nil error:&error]);
	XCTAssertNotNil(error);
	XCTAssertTrue([PBGitRepository isRejectedPushError:error], @"%@", error);

	error = nil;
	XCTAssertTrue([repository pushBranch:feature toRemote:nil forceWithLeaseExpecting:expectedSHA error:&error], @"%@", error);
}

- (void)testTheLeaseRefusesWhenTheRemoteMovedOnAfterItWasLastSeen
{
	NSString *remote = [self bareRemoteWithMaster];
	PBGitRepository *repository = [self rewrittenCloneOfRemoteAt:remote];
	PBGitRef *feature = [PBGitRef refFromString:@"refs/heads/feature"];
	NSString *expectedSHA = [repository remoteTrackingSHAForBranch:feature toRemote:nil];

	NSString *other = [self.sandbox stringByAppendingPathComponent:@"other"];
	XCTAssertTrue(([self runGit:@[ @"clone", @"--quiet", @"--branch", @"feature", remote, other ] inDirectory:self.sandbox]));
	XCTAssertTrue(([self runGit:@[ @"commit", @"--quiet", @"--allow-empty", @"-m", @"someone else's work" ] inDirectory:other]));
	XCTAssertTrue(([self runGit:@[ @"push", @"--quiet", @"origin", @"feature" ] inDirectory:other]));

	NSError *error = nil;
	XCTAssertFalse([repository pushBranch:feature toRemote:nil forceWithLeaseExpecting:expectedSHA error:&error]);
	XCTAssertNotNil(error);
	XCTAssertFalse([PBGitRepository isRejectedPushError:error], @"a stale lease must not offer another force: %@", error);
}

- (void)testALeaseWithoutAnExpectedSHARefusesWhenTheRemoteBranchExists
{
	NSString *remote = [self bareRemoteWithMaster];
	PBGitRepository *repository = [self rewrittenCloneOfRemoteAt:remote];
	PBGitRef *feature = [PBGitRef refFromString:@"refs/heads/feature"];

	NSError *error = nil;
	XCTAssertFalse([repository pushBranch:feature toRemote:nil forceWithLeaseExpecting:nil error:&error]);
	XCTAssertNotNil(error);
	XCTAssertFalse([PBGitRepository isRejectedPushError:error], @"%@", error);
}

@end
