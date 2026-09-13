//
//  OpenRecentControllerErrorTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "OpenRecentController.h"

// Takes the selection a test hands it, and records the failure instead of
// putting an alert on screen.
@interface PBRecordingOpenRecentController : OpenRecentController
@property (nonatomic, strong) NSError *reportedError;
@property (nonatomic, assign) NSUInteger reportCount;
- (void)useSelectedResult:(NSURL *)url;
@end

@implementation PBRecordingOpenRecentController

- (void)useSelectedResult:(NSURL *)url
{
	selectedResult = url;
}

- (void)reportFailureToOpen:(NSError *)error
{
	self.reportCount++;
	self.reportedError = error;
}

@end

@interface OpenRecentControllerErrorTests : XCTestCase
@property (nonatomic, strong) PBRecordingOpenRecentController *controller;
@property (nonatomic, strong) NSURL *directory;
@end

@implementation OpenRecentControllerErrorTests

- (void)setUp
{
	[super setUp];

	self.controller = [[PBRecordingOpenRecentController alloc] init];

	self.directory = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]]];
	[[NSFileManager defaultManager] createDirectoryAtURL:self.directory
							withIntermediateDirectories:YES
											 attributes:nil
												  error:NULL];
}

- (void)tearDown
{
	[[NSFileManager defaultManager] removeItemAtURL:self.directory error:NULL];

	[super tearDown];
}

- (void)waitForReportUpTo:(NSTimeInterval)seconds
{
	NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
	while (self.controller.reportCount == 0 && [deadline timeIntervalSinceNow] > 0)
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

- (void)testAnEntryThatCannotBeOpenedIsReported
{
	[self.controller useSelectedResult:self.directory];

	[self.controller openSelectedResult];
	[self waitForReportUpTo:10];

	XCTAssertEqual(self.controller.reportCount, 1u, @"the recents list is the only thing the user can see this fail in");
	XCTAssertNotNil(self.controller.reportedError, @"there is nothing to put on screen without the error");
}

- (void)testNothingIsReportedWithoutASelection
{
	[self.controller openSelectedResult];
	[self waitForReportUpTo:0.5];

	XCTAssertEqual(self.controller.reportCount, 0u);
}

@end
