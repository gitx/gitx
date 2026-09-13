//
//  PBGitIndexDiffCacheTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBChangedFile.h"
#import "PBGitIndex.h"
#import "PBGitRepository.h"
#import "PBGitRepository_PBGitBinarySupport.h"

// Records the diff git is asked for instead of running it, and points the two
// paths the cache stats at a temporary directory the test owns.
@interface PBDiffStubRepository : PBGitRepository
@property (nonatomic, strong) NSURL *workingURL;
@property (nonatomic, strong) NSURL *indexFileURL;
@property (nonatomic, strong) NSMutableArray<NSArray<NSString *> *> *askedFor;
@end

@implementation PBDiffStubRepository

- (instancetype)init
{
	if (!(self = [super init]))
		return nil;

	_askedFor = [NSMutableArray array];

	return self;
}

- (NSURL *)workingDirectoryURL
{
	return self.workingURL;
}

- (NSURL *)getIndexURL
{
	return self.indexFileURL;
}

// So that -parentTree names HEAD and HEAD^ rather than falling back to the
// empty tree for both, which is what an amend has to be told apart by.
- (BOOL)revisionExists:(NSString *)spec
{
	return YES;
}

- (NSString *)outputOfTaskWithArguments:(NSArray *)arguments error:(NSError **)error
{
	[self.askedFor addObject:arguments ?: @[]];

	return [NSString stringWithFormat:@"diff %lu", (unsigned long)self.askedFor.count];
}

@end

// Setting amend asks the index to read itself back, which launches git. These
// tests answer for git themselves, so the read-back stays out of them.
@interface PBQuietIndex : PBGitIndex
@end

@implementation PBQuietIndex

- (void)refresh
{
}

@end

@interface PBGitIndexDiffCacheTests : XCTestCase
@property (nonatomic, strong) PBDiffStubRepository *repository;
@property (nonatomic, strong) PBGitIndex *gitIndex;
@property (nonatomic, strong) NSURL *directory;
@end

@implementation PBGitIndexDiffCacheTests

- (void)setUp
{
	[super setUp];

	self.directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]];
	[[NSFileManager defaultManager] createDirectoryAtURL:self.directory
							withIntermediateDirectories:YES
											 attributes:nil
												  error:NULL];

	[self write:@"one\n" to:@"a.txt"];
	[self write:@"index contents" to:@"index"];

	// The index holds its repository weakly, so the test case owns them both
	self.repository = [[PBDiffStubRepository alloc] init];
	self.repository.workingURL = self.directory;
	self.repository.indexFileURL = [self.directory URLByAppendingPathComponent:@"index"];
	self.gitIndex = [[PBQuietIndex alloc] initWithRepository:self.repository];
}

- (void)tearDown
{
	[[NSFileManager defaultManager] removeItemAtURL:self.directory error:NULL];

	[super tearDown];
}

- (void)write:(NSString *)contents to:(NSString *)name
{
	NSURL *url = [self.directory URLByAppendingPathComponent:name];
	[contents writeToURL:url atomically:NO encoding:NSUTF8StringEncoding error:NULL];
}

- (PBChangedFile *)modifiedFile
{
	PBChangedFile *file = [[PBChangedFile alloc] initWithPath:@"a.txt"];
	file.status = MODIFIED;
	file.hasUnstagedChanges = YES;

	return file;
}

- (NSString *)unstagedDiff
{
	return [self.gitIndex diffForFile:[self modifiedFile] staged:NO contextLines:3];
}

#pragma mark A diff nothing could have changed is not asked for twice

- (void)testTheSameDiffIsAskedForOnlyOnce
{
	NSString *first = [self unstagedDiff];
	NSString *second = [self unstagedDiff];

	XCTAssertEqual(self.repository.askedFor.count, 1u,
				   @"nothing about the file or the index changed between the two");
	XCTAssertEqualObjects(second, first);
}

- (void)testADifferentContextSizeIsAskedFor
{
	[self.gitIndex diffForFile:[self modifiedFile] staged:NO contextLines:3];
	[self.gitIndex diffForFile:[self modifiedFile] staged:NO contextLines:6];

	XCTAssertEqual(self.repository.askedFor.count, 2u);
	XCTAssertEqualObjects(self.repository.askedFor.lastObject,
						  (@[ @"diff-files", @"-U6", @"--", @"a.txt" ]));
}

- (void)testTheStagedDiffIsAskedForSeparately
{
	[self.gitIndex diffForFile:[self modifiedFile] staged:NO contextLines:3];
	[self.gitIndex diffForFile:[self modifiedFile] staged:YES contextLines:3];

	XCTAssertEqual(self.repository.askedFor.count, 2u);
	XCTAssertEqualObjects(self.repository.askedFor.lastObject.firstObject, @"diff-index");
}

#pragma mark A diff that could have changed is asked for again

- (void)testEditingTheWorkingFileIsAskedForAgain
{
	NSString *first = [self unstagedDiff];
	[self write:@"one\ntwo\n" to:@"a.txt"];
	NSString *second = [self unstagedDiff];

	XCTAssertEqual(self.repository.askedFor.count, 2u);
	XCTAssertNotEqualObjects(second, first);
}

- (void)testWritingTheIndexIsAskedForAgain
{
	[self unstagedDiff];
	[self write:@"index contents, changed" to:@"index"];
	[self unstagedDiff];

	XCTAssertEqual(self.repository.askedFor.count, 2u);
}

- (void)testAmendingIsAskedForAgain
{
	[self.gitIndex diffForFile:[self modifiedFile] staged:YES contextLines:3];
	self.gitIndex.amend = YES;
	[self.gitIndex diffForFile:[self modifiedFile] staged:YES contextLines:3];

	XCTAssertEqual(self.repository.askedFor.count, 2u);
}

@end
