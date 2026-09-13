//
//  GLFileViewContentCacheTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "GLFileView.h"
#import "PBGitHistoryController.h"
#import "PBGitRepository.h"
#import "PBGitRepository_PBGitBinarySupport.h"
#import "PBGitTree.h"

static NSString *const kHeadSHA = @"1ce0aa2100000000000000000000000000000fee";
static NSString *const kCommitSHA = @"30e1c43c00000000000000000000000000000abc";

// Records what git is asked for instead of running it, and names a HEAD
// without a repository on disk to look it up in.
@interface PBFileStubRepository : PBGitRepository
@property (nonatomic, strong) NSMutableArray<NSArray<NSString *> *> *askedFor;
@property (nonatomic, strong) GTOID *head;
@end

@implementation PBFileStubRepository

- (instancetype)init
{
	if (!(self = [super init]))
		return nil;

	_askedFor = [NSMutableArray array];
	_head = [GTOID oidWithSHA:kHeadSHA];

	return self;
}

- (GTOID *)headOID
{
	return self.head;
}

- (NSString *)outputOfTaskWithArguments:(NSArray *)arguments error:(NSError **)error
{
	[self.askedFor addObject:arguments ?: @[]];

	if ([arguments.firstObject isEqualToString:@"cat-file"])
		return @"12";

	return @"file contents";
}

@end

// The file view picks the file out of the history controller's tree, which a
// standalone tree controller can hold just as well as the nib's one.
@interface PBFileStubHistoryController : PBGitHistoryController
@property (nonatomic, strong) NSTreeController *tree;
@end

@implementation PBFileStubHistoryController

- (NSTreeController *)treeController
{
	return self.tree;
}

@end

// The history controller is an outlet, so a test has to hand it over itself.
@interface PBStubFileView : GLFileView
- (void)useHistoryController:(PBGitHistoryController *)controller;
@end

@implementation PBStubFileView

- (void)useHistoryController:(PBGitHistoryController *)controller
{
	historyController = controller;
}

@end

@interface GLFileViewContentCacheTests : XCTestCase
@property (nonatomic, strong) PBFileStubRepository *repository;
@property (nonatomic, strong) PBFileStubHistoryController *historyController;
@property (nonatomic, strong) PBStubFileView *fileView;
@property (nonatomic, strong) PBGitTree *root;
@end

@implementation GLFileViewContentCacheTests

- (void)setUp
{
	[super setUp];

	self.repository = [[PBFileStubRepository alloc] init];

	self.root = [[PBGitTree alloc] init];
	self.root.repository = self.repository;
	self.root.sha = kCommitSHA;
	self.root.path = @"";
	self.root.leaf = NO;

	NSTreeController *tree = [[NSTreeController alloc] init];
	tree.childrenKeyPath = @"children";
	tree.leafKeyPath = @"leaf";
	tree.content = @[ [self fileNamed:@"one.txt"], [self fileNamed:@"two.txt"] ];

	// The view holds its history controller weakly, so the test case owns them
	self.historyController = [[PBFileStubHistoryController alloc] initWithRepository:self.repository superController:nil];
	self.historyController.tree = tree;

	self.fileView = [[PBStubFileView alloc] init];
	self.fileView.startFile = @"fileview";
	[self.fileView useHistoryController:self.historyController];

	[self selectFileAtIndex:0];
}

- (PBGitTree *)fileNamed:(NSString *)name
{
	PBGitTree *file = [PBGitTree treeForTree:self.root andPath:name];
	file.leaf = YES;

	return file;
}

- (void)selectFileAtIndex:(NSUInteger)index
{
	[self.historyController.treeController setSelectionIndexPath:[NSIndexPath indexPathWithIndex:index]];
}

- (NSUInteger)readsSoFar
{
	return self.repository.askedFor.count;
}

- (void)testTheSameFileIsReadOnlyOnce
{
	[self.fileView showFile];
	NSUInteger afterFirstShow = [self readsSoFar];

	[self.fileView showFile];

	XCTAssertGreaterThan(afterFirstShow, 0, @"the file view has to read the file at least once");
	XCTAssertEqual([self readsSoFar], afterFirstShow, @"showing the same file again is not worth another read");
}

- (void)testAnotherFileIsReadOnItsOwn
{
	[self.fileView showFile];
	NSUInteger afterFirstShow = [self readsSoFar];

	[self selectFileAtIndex:1];
	[self.fileView showFile];

	XCTAssertGreaterThan([self readsSoFar], afterFirstShow, @"a different file is a different read");
}

- (void)testAnotherTabIsReadOnItsOwn
{
	[self.fileView showFile];
	NSUInteger afterFirstShow = [self readsSoFar];

	self.fileView.startFile = @"blame";
	[self.fileView showFile];

	XCTAssertGreaterThan([self readsSoFar], afterFirstShow, @"the blame of a file is not its contents");
}

- (void)testAReloadedPageIsFilledInAgain
{
	[self.fileView showFile];
	NSUInteger afterFirstShow = [self readsSoFar];

	[self.fileView didLoad];

	XCTAssertGreaterThan([self readsSoFar], afterFirstShow, @"a page that reloaded has nothing on it to keep");
}

- (void)testAMovedHeadIsReadAgain
{
	[self.fileView showFile];
	NSUInteger afterFirstShow = [self readsSoFar];

	self.repository.head = [GTOID oidWithSHA:kCommitSHA];
	[self.fileView showFile];

	XCTAssertGreaterThan([self readsSoFar], afterFirstShow, @"a new commit can change what the file's history says");
}

@end
