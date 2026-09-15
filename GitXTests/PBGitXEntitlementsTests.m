//
//  PBGitXEntitlementsTests.m
//  GitXTests
//

#import <XCTest/XCTest.h>
#import <Security/Security.h>

// Opening a repository in Terminal or iTerm2 is carried entirely by an Apple
// event, which the hardened runtime refuses to send for an application that does
// not ask for the privilege. Released builds are signed with that runtime, so
// without the entitlement the event is rejected below the consent layer: the
// terminal is launched but the command never arrives, and nothing tells the user.
@interface PBGitXEntitlementsTests : XCTestCase
@end

@implementation PBGitXEntitlementsTests

- (void)testTheApplicationIsAllowedToSendAppleEvents
{
	SecTaskRef task = SecTaskCreateFromSelf(kCFAllocatorDefault);
	XCTAssertTrue(task != NULL, @"the test host should be a signed task");

	CFTypeRef entitlement = SecTaskCopyValueForEntitlement(task, CFSTR("com.apple.security.automation.apple-events"), NULL);
	CFRelease(task);

	XCTAssertTrue(entitlement == kCFBooleanTrue, @"GitX cannot drive a terminal application without this entitlement");

	if (entitlement)
		CFRelease(entitlement);
}

@end
