//
//  PBOpenDocumentCommand.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-07.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBOpenDocumentCommand.h"
#import "PBRepositoryDocumentController.h"
#import "PBGitRepository.h"

@implementation PBOpenDocumentCommand

- (id) initWithDocumentAbsolutePath:(NSString *) path {
	if ((self = [super initWithDisplayName:@"Open" parameters:nil repository:nil])) {
		documentURL = [[NSURL alloc] initWithString:path];
	}
	return self;
}

- (void) invoke {
	[[PBRepositoryDocumentController sharedDocumentController] documentForLocation:documentURL];
}

@end
