//
//  PBTaskTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import "PBTask.h"

@interface PBTaskTests : XCTestCase
@end

@implementation PBTaskTests

- (void)testShortTasksRunningConcurrentlyKeepAllTheirOutput
{
	const NSUInteger taskCount = 400;
	NSString *expected = @"git version 2.0.0\n";
	NSLock *lock = [[NSLock alloc] init];
	NSMutableArray<NSString *> *wrong = [NSMutableArray array];

	dispatch_apply(taskCount, dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^(size_t index) {
		NSError *error = nil;
		NSString *output = [PBTask outputForCommand:@"/bin/echo" arguments:@[ @"git version 2.0.0" ] error:&error];
		if (![output isEqualToString:expected]) {
			[lock lock];
			[wrong addObject:[NSString stringWithFormat:@"#%zu: %@ (%@)", index, output ? [NSString stringWithFormat:@"'%@'", output] : @"nil", error]];
			[lock unlock];
		}
	});

	XCTAssertEqual(wrong.count, 0u, @"tasks that lost their output: %@", wrong);
}

@end
