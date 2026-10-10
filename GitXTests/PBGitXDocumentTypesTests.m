#import <XCTest/XCTest.h>
#import <CoreServices/CoreServices.h>

#import "PBRepositoryDocumentController.h"
#import "PBGitRepositoryDocument.h"

@interface PBGitXDocumentTypesTests : XCTestCase
@end

@implementation PBGitXDocumentTypesTests

- (void)testLaunchServicesAcceptsFolderDrops
{
	NSURL *applicationURL = [NSBundle mainBundle].bundleURL;
	XCTAssertEqual(LSRegisterURL((__bridge CFURLRef)applicationURL, true), noErr);

	NSURL *temporaryDirectory = [[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES]
		URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	for (NSString *name in @[@"repository", @"repository.with.dots", @"bare.git"]) {
		NSURL *folderURL = [temporaryDirectory URLByAppendingPathComponent:name isDirectory:YES];
		NSError *error = nil;
		XCTAssertTrue([fileManager createDirectoryAtURL:folderURL withIntermediateDirectories:YES attributes:nil error:&error], @"%@", error);

		// This is the acceptance check used before delivering an open event;
		// repository discovery cannot help if Launch Services refuses the drop.
		Boolean accepts = false;
		XCTAssertEqual(LSCanURLAcceptURL((__bridge CFURLRef)folderURL, (__bridge CFURLRef)applicationURL,
			kLSRolesViewer, kLSAcceptDefault, &accepts), noErr);
		XCTAssertTrue(accepts, @"GitX must accept a folder named %@ as a drop target", name);
	}
	[fileManager removeItemAtURL:temporaryDirectory error:nil];
}

- (void)testFolderDocumentsUseTheRepositoryDocumentClass
{
	NSDocumentController *controller = [PBRepositoryDocumentController sharedDocumentController];
	XCTAssertEqual([controller documentClassForType:@"public.folder"], [PBGitRepositoryDocument class]);
	NSError *error = nil;
	NSString *type = [controller typeForContentsOfURL:[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] error:&error];
	XCTAssertNotNil(type, @"%@", error);
	XCTAssertEqual([controller documentClassForType:type], [PBGitRepositoryDocument class]);
}

@end
