//
//  PBGitRevListEnumerationErrorTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import <ObjectiveGit/ObjectiveGit.h>
#import "PBGitRevList.h"

// Exposes the walk itself, so the failure can be driven directly rather than by
// arranging for a real repository to break under a running load.
@interface PBGitRevList (EnumerationErrorTesting)
- (void)addCommitsFromEnumerator:(GTEnumerator *)enumerator operation:(NSOperation *)operation generation:(NSUInteger)generation;
@end

// Stands in for an enumerator whose walk cannot continue, which is what a
// repository being deleted, moved or unmounted produces. The walk only ever asks
// it for the next OID, so none of the rest of GTEnumerator is needed here.
@interface PBFailingEnumerator : NSObject
@end

@implementation PBFailingEnumerator

- (GTOID *)nextOIDWithSuccess:(BOOL *)success error:(NSError **)error
{
	if (success) {
		*success = NO;
	}
	if (error) {
		*error = [NSError errorWithDomain:GTGitErrorDomain
									 code:-1
								 userInfo:@{NSLocalizedDescriptionKey : @"the walk could not be continued"}];
	}
	return nil;
}

@end

@interface PBGitRevListEnumerationErrorTests : XCTestCase
@end

@implementation PBGitRevListEnumerationErrorTests

// A walk that fails part-way used to end on NSAssert(!enumError, ...), raising
// NSInternalInconsistencyException. Assertions are live in Release too, so the
// repository changing under an open window took the application down with no
// sheet and nothing said about the error that was already in hand.
- (void)testAFailedWalkDoesNotRaise
{
	PBGitRevList *revList = [[PBGitRevList alloc] initWithRepository:nil rev:nil shouldGraph:NO];
	PBFailingEnumerator *enumerator = [[PBFailingEnumerator alloc] init];

	XCTAssertNoThrow([revList addCommitsFromEnumerator:(GTEnumerator *)enumerator
											operation:[[NSOperation alloc] init]
										   generation:1]);
}

@end
