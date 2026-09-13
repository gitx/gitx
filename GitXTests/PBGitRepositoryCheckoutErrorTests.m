//
//  PBGitRepositoryCheckoutErrorTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBGitRepository.h"
#import "PBTask.h"

// The reason a failed git task is reported with is private to the repository,
// so the test names it the way the other suites name the seams they drive.
@interface PBGitRepository (CheckoutErrorTesting)
- (NSString *)failureReasonFromTaskError:(NSError *)taskError orFallback:(NSString *)fallback;
@end

static NSString *const kWorktreeRefusal = @"fatal: 'feature' is already used by worktree at '/tmp/other-worktree'";
static NSString *const kGuess = @"There was an error checking out the branch 'feature'.\n\nPerhaps your working directory is not clean?";

@interface PBGitRepositoryCheckoutErrorTests : XCTestCase
@property (nonatomic, strong) PBGitRepository *repository;
@end

@implementation PBGitRepositoryCheckoutErrorTests

- (void)setUp
{
	[super setUp];

	// The reason does not depend on the repository it is reported for, and
	// -[PBGitRepository init] reaches for neither libgit2 nor git.
	self.repository = [[PBGitRepository alloc] init];
}

- (NSError *)taskErrorWithOutput:(NSString *)output
{
	return [NSError errorWithDomain:PBTaskErrorDomain
							   code:PBTaskNonZeroExitCodeError
						   userInfo:@{PBTaskTerminationStatusKey : @128,
									  PBTaskTerminationOutputKey : output}];
}

// The bug (#629): git refuses the checkout because the branch is checked out in
// another worktree, and GitX reported a guess about the working directory
// instead, which sends the reader looking for changes that are not there.
- (void)testGitsOwnRefusalIsReportedInsteadOfTheGuess
{
	NSError *taskError = [self taskErrorWithOutput:kWorktreeRefusal];

	XCTAssertEqualObjects([self.repository failureReasonFromTaskError:taskError orFallback:kGuess], kWorktreeRefusal);
}

- (void)testGitsOutputIsTrimmed
{
	NSError *taskError = [self taskErrorWithOutput:[kWorktreeRefusal stringByAppendingString:@"\n"]];

	XCTAssertEqualObjects([self.repository failureReasonFromTaskError:taskError orFallback:kGuess], kWorktreeRefusal);
}

- (void)testTheFallbackIsKeptWhenGitSaidNothing
{
	NSError *taskError = [self taskErrorWithOutput:@"  \n "];

	XCTAssertEqualObjects([self.repository failureReasonFromTaskError:taskError orFallback:kGuess], kGuess);
}

- (void)testTheFallbackIsKeptForAFailureThatIsNotATaskError
{
	NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0 userInfo:nil];

	XCTAssertEqualObjects([self.repository failureReasonFromTaskError:error orFallback:kGuess], kGuess);
}

@end
