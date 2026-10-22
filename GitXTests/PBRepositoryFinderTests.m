//
//  PBRepositoryFinderTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBRepositoryFinder.h"
#import "PBGitBinary.h"
#import "PBGitRepository.h"

@interface PBGitBinary (ReftableTesting)
+ (NSString *)versionForPath:(NSString *)path;
@end

// The finder hands libgit2 a git_buf and turns the bytes it writes back into a
// path, so these need a repository that actually exists on disk rather than the
// stubs the other suites here use.
@interface PBRepositoryFinderTests : XCTestCase
@property (nonatomic, strong) NSURL *workDir;
@end

@interface PBReftableRepositoryTests : XCTestCase
@property (nonatomic, strong) NSURL *workDir;
@property (nonatomic, copy) NSString *gitPath;
@end

@implementation PBReftableRepositoryTests

- (NSString *)git:(NSArray<NSString *> *)arguments
{
	NSTask *task = [[NSTask alloc] init];
	task.executableURL = [NSURL fileURLWithPath:self.gitPath];
	task.arguments = [@[@"-C", self.workDir.path] arrayByAddingObjectsFromArray:arguments];
	task.environment = @{
		@"PATH" : @"/usr/bin:/bin",
		@"GIT_CONFIG_GLOBAL" : @"/dev/null",
		@"GIT_CONFIG_SYSTEM" : @"/dev/null",
		@"GIT_AUTHOR_NAME" : @"GitX Tests",
		@"GIT_AUTHOR_EMAIL" : @"tests@example.invalid",
		@"GIT_COMMITTER_NAME" : @"GitX Tests",
		@"GIT_COMMITTER_EMAIL" : @"tests@example.invalid"
	};
	NSPipe *output = [NSPipe pipe];
	task.standardOutput = output;
	task.standardError = NSFileHandle.fileHandleWithNullDevice;
	NSError *error = nil;
	BOOL launched = [task launchAndReturnError:&error];
	XCTAssertTrue(launched, @"git %@ did not start: %@", arguments, error);
	if (!launched)
		return nil;
	NSData *data = [output.fileHandleForReading readDataToEndOfFile];
	[task waitUntilExit];
	XCTAssertEqual(task.terminationStatus, 0, @"git %@ failed", arguments);
	return [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
		stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

- (void)setUp
{
	[super setUp];
	NSString *configured = NSProcessInfo.processInfo.environment[@"GITX_TEST_GIT"];
	NSArray *candidates = configured ? @[configured] : @[@"/opt/homebrew/bin/git", @"/usr/local/bin/git", @"/usr/bin/git"];
	for (NSString *candidate in candidates) {
		NSString *version = [PBGitBinary versionForPath:candidate];
		if (version && [version compare:@"2.45" options:NSNumericSearch] != NSOrderedAscending) {
			self.gitPath = candidate;
			break;
		}
	}
	if (configured && !self.gitPath) {
		XCTFail(@"GITX_TEST_GIT must point to Git >= 2.45: %@", configured);
		return;
	}
	XCTSkipIf(self.gitPath == nil, @"Reftable integration tests require Git >= 2.45; set GITX_TEST_GIT to its executable.");

	self.workDir = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
		URLByAppendingPathComponent:[NSString stringWithFormat:@"GitXReftable-%@", NSUUID.UUID.UUIDString]
						isDirectory:YES];
	NSError *error = nil;
	XCTAssertTrue([NSFileManager.defaultManager createDirectoryAtURL:self.workDir
									   withIntermediateDirectories:YES
														attributes:nil
															 error:&error], @"%@", error);
	[self git:@[@"init", @"--quiet", @"--ref-format=reftable", @"--initial-branch=main"]];
	[self git:@[@"-c", @"commit.gpgsign=false", @"commit", @"--quiet", @"--allow-empty", @"-m", @"Initial"]];
	[self git:@[@"tag", @"initial"]];
	XCTAssertEqualObjects(([self git:@[@"config", @"extensions.refStorage"]]), @"reftable");
}

- (void)tearDown
{
	if (self.workDir)
		[NSFileManager.defaultManager removeItemAtURL:self.workDir error:NULL];
	[super tearDown];
}

- (void)testDiscoversAndOpensAReftableRepositoryWithoutConversion
{
	NSURL *nested = [self.workDir URLByAppendingPathComponent:@"one/two" isDirectory:YES];
	[NSFileManager.defaultManager createDirectoryAtURL:nested withIntermediateDirectories:YES attributes:nil error:NULL];
	NSURL *expectedGitDir = [self.workDir URLByAppendingPathComponent:@".git" isDirectory:YES];
	XCTAssertEqualObjects([PBRepositoryFinder gitDirForURL:nested].URLByResolvingSymlinksInPath.path,
						 expectedGitDir.URLByResolvingSymlinksInPath.path);
	XCTAssertEqualObjects([PBRepositoryFinder fileURLForURL:nested].URLByResolvingSymlinksInPath.path,
						 self.workDir.URLByResolvingSymlinksInPath.path);

	NSError *error = nil;
	PBGitRepository *repository = [[PBGitRepository alloc] initWithURL:nested error:&error];
	XCTAssertNotNil(repository, @"%@", error);
	XCTAssertNotNil([repository.gtRepo lookUpReferenceWithName:@"refs/heads/main" error:&error], @"%@", error);
	XCTAssertNotNil([repository.gtRepo lookUpReferenceWithName:@"refs/tags/initial" error:&error], @"%@", error);
	XCTAssertEqualObjects([repository.gtRepo headReferenceWithError:&error].targetOID.SHA, ([self git:@[@"rev-parse", @"HEAD"]]));
	XCTAssertEqualObjects(([self git:@[@"config", @"extensions.refStorage"]]), @"reftable");
}

- (void)testNativeReferenceWritesAndExternalUpdates
{
	NSError *error = nil;
	GTRepository *repository = [GTRepository repositoryWithURL:self.workDir error:&error];
	XCTAssertNotNil(repository, @"%@", error);
	if (!repository)
		return;
	git_repository *repo = repository.git_repository;
	git_oid oid;
	XCTAssertEqual(git_reference_name_to_id(&oid, repo, "HEAD"), 0);
	git_reference *branch = NULL, *renamed = NULL;
	XCTAssertEqual(git_reference_create(&branch, repo, "refs/heads/native", &oid, 0, "Create native branch"), 0);
	if (!branch)
		return;
	XCTAssertEqualObjects(([self git:@[@"rev-parse", @"native"]]), ([self git:@[@"rev-parse", @"main"]]));
	XCTAssertEqual(git_reference_rename(&renamed, branch, "refs/heads/renamed", 0, "Rename native branch"), 0);
	git_reference_free(branch);
	if (renamed) {
		XCTAssertEqual(git_reference_delete(renamed), 0);
		git_reference_free(renamed);
	}
	XCTAssertFalse(([[self git:@[@"for-each-ref", @"--format=%(refname)"]] containsString:@"refs/heads/renamed"]));
	[self git:@[@"branch", @"external"]];
	XCTAssertNotNil([repository lookUpReferenceWithName:@"refs/heads/external" error:&error], @"%@", error);
	git_reflog *log = NULL;
	XCTAssertEqual(git_reflog_read(&log, repo, "HEAD"), 0);
	if (log)
		XCTAssertGreaterThan(git_reflog_entrycount(log), (size_t)0);
	git_reflog_free(log);
	XCTAssertEqualObjects(([self git:@[@"config", @"extensions.refStorage"]]), @"reftable");
}

- (void)testNativeStagingCommitAndHistory
{
	NSError *error = nil;
	GTRepository *repository = [GTRepository repositoryWithURL:self.workDir error:&error];
	XCTAssertNotNil(repository, @"%@", error);
	if (!repository)
		return;
	XCTAssertTrue([@"Reftable commit\n" writeToURL:[self.workDir URLByAppendingPathComponent:@"tracked.txt"]
									  atomically:YES encoding:NSUTF8StringEncoding error:&error], @"%@", error);
	git_repository *repo = repository.git_repository;
	git_index *index = NULL;
	git_tree *tree = NULL;
	git_commit *parent = NULL;
	git_signature *signature = NULL;
	git_oid parentOID, treeOID, commitOID;
	XCTAssertEqual(git_repository_index(&index, repo), 0);
	if (!index)
		return;
	XCTAssertEqual(git_index_add_bypath(index, "tracked.txt"), 0);
	XCTAssertEqual(git_index_write(index), 0);
	XCTAssertEqual(git_index_write_tree(&treeOID, index), 0);
	XCTAssertEqual(git_tree_lookup(&tree, repo, &treeOID), 0);
	XCTAssertEqual(git_reference_name_to_id(&parentOID, repo, "HEAD"), 0);
	XCTAssertEqual(git_commit_lookup(&parent, repo, &parentOID), 0);
	XCTAssertEqual(git_signature_now(&signature, "GitX Tests", "tests@example.invalid"), 0);
	if (tree && parent && signature) {
		XCTAssertEqual(git_commit_create_v(&commitOID, repo, "HEAD", signature, signature, NULL,
										 "Native reftable commit", tree, 1, parent), 0);
		XCTAssertEqualObjects([repository headReferenceWithError:&error].targetOID.SHA, ([self git:@[@"rev-parse", @"HEAD"]]));
		GTEnumerator *history = [[GTEnumerator alloc] initWithRepository:repository error:&error];
		XCTAssertTrue([history pushHEAD:&error], @"%@", error);
		NSArray *commits = [history allObjectsWithError:&error];
		XCTAssertEqual(commits.count, (NSUInteger)2, @"%@", error);
		XCTAssertEqualObjects(([self git:@[@"rev-list", @"--count", @"HEAD"]]), @"2");
		XCTAssertEqualObjects(([self git:@[@"status", @"--porcelain"]]), @"");
	}
	git_signature_free(signature);
	git_commit_free(parent);
	git_tree_free(tree);
	git_index_free(index);
}

- (void)testBareRepositoryAndLinkedWorktree
{
	NSURL *bare = [self.workDir URLByAppendingPathComponent:@"bare.git" isDirectory:YES];
	[self git:@[@"clone", @"--quiet", @"--bare", @"--ref-format=reftable", @".", bare.path]];
	XCTAssertEqualObjects(([self git:@[@"--git-dir", bare.path, @"config", @"extensions.refStorage"]]), @"reftable");
	NSError *error = nil;
	GTRepository *bareRepo = [GTRepository repositoryWithURL:bare error:&error];
	XCTAssertNotNil(bareRepo, @"%@", error);
	XCTAssertTrue(bareRepo.isBare);
	XCTAssertEqualObjects([PBRepositoryFinder fileURLForURL:bare].URLByResolvingSymlinksInPath.path,
						 bare.URLByResolvingSymlinksInPath.path);

	NSURL *linked = [self.workDir URLByAppendingPathComponent:@"linked" isDirectory:YES];
	[self git:@[@"worktree", @"add", @"--quiet", @"-b", @"linked", linked.path]];
	GTRepository *linkedRepo = [GTRepository repositoryWithURL:linked error:&error];
	XCTAssertNotNil(linkedRepo, @"%@", error);
	XCTAssertEqualObjects([PBRepositoryFinder workDirForURL:linked].URLByResolvingSymlinksInPath.path,
						 linked.URLByResolvingSymlinksInPath.path);
	XCTAssertEqualObjects([linkedRepo headReferenceWithError:&error].name, @"refs/heads/linked");
	XCTAssertNotNil([linkedRepo lookUpReferenceWithName:@"refs/heads/main" error:&error], @"%@", error);
}

- (void)testRejectsSHA256WithoutTruncatingObjectIDs
{
	NSURL *sha256 = [self.workDir URLByAppendingPathComponent:@"sha256" isDirectory:YES];
	[self git:@[@"init", @"--quiet", @"--object-format=sha256", @"--ref-format=reftable", sha256.path]];
	NSError *error = nil;
	PBGitRepository *repository = [[PBGitRepository alloc] initWithURL:sha256 error:&error];
	XCTAssertNil(repository);
	XCTAssertTrue([error.localizedFailureReason containsString:@"SHA-256"], @"%@", error);
}

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
