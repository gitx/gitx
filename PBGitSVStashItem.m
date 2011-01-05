//
//  PBGitSVStashItem.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBGitSVStashItem.h"


@implementation PBGitSVStashItem
@synthesize stash;

#pragma mark -
#pragma mark Inits/dealloc
//---------------------------------------------------------------------------------------------

- initWithStash:(PBGitStash *) aStash {
	if (self = [super init]) {
		NSString *displayTitle = [NSString stringWithFormat:@"%@ (%@)", [aStash message], [aStash stashSourceMessage]];
		super.title = displayTitle;
		stash = [aStash retain];
	}
	return self;
}

- (void) dealloc {
	[stash release];
	[super dealloc];
}

//---------------------------------------------------------------------------------------------
#pragma mark -


- (NSImage *) icon {
	static NSImage *tagImage = nil;
	if (!tagImage)
		tagImage = [NSImage imageNamed:@"stash-icon.png"];
	
	return tagImage;
}

@end
