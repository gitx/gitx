//
//  PBOpenFiles.m
//  GitX
//
//  Created by Tommy Sparber on 02/08/16.
//  Based on code by Etienne
//

#import "PBOpenFiles.h"
#import "PBChangedFile.h"

@implementation PBOpenFiles

+ (NSArray *) selectedURLsFromSender:(NSArray<PBChangedFile *> *)selectedFiles with:(NSURL *)workingDirectoryURL {
	if ([selectedFiles count] == 0)
		return nil;

	NSMutableArray *URLs = [NSMutableArray array];
	for (id file in selectedFiles) {
		NSString *path = file;
		// Those can be PBChangedFiles sent by PBGitIndexController. Get their path.
		if ([file respondsToSelector:@selector(path)]) {
			path = [file path];
		}

		if (![path isKindOfClass:[NSString class]])
			continue;
		[URLs addObject:[workingDirectoryURL URLByAppendingPathComponent:path]];
	}

	return URLs;
}

+ (void) openFiles:(NSArray<PBChangedFile *> *)selectedFiles with:(NSURL *)workingDirectoryURL {
	NSArray *URLs = [self selectedURLsFromSender:selectedFiles with:workingDirectoryURL];
	
	if ([URLs count] == 0)
		return;
	
	[[NSWorkspace sharedWorkspace] openURLs:URLs
					withAppBundleIdentifier:nil
									options:0
			 additionalEventParamDescriptor:nil
						  launchIdentifiers:NULL];
}

+ (void) showInFinder:(NSArray<PBChangedFile *> *)selectedFiles with:(NSURL *)workingDirectoryURL {
	NSArray *URLs = [self selectedURLsFromSender:selectedFiles with:workingDirectoryURL];
	if ([URLs count] == 0)
		return;

	[[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:URLs];
}

@end
