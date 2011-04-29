//
//  PBGitSVStashItem.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBGitMenuItem.h"


@implementation PBGitMenuItem
@synthesize sourceObject;

#pragma mark -
#pragma mark Inits/dealloc
//---------------------------------------------------------------------------------------------

- initWithSourceObject:(id<PBPresentable>) anObject {
	if ((self = [super init])) {
		super.title = [anObject displayDescription];
		sourceObject = [anObject retain];
	}
	return self;
}

- (void) dealloc {
	[sourceObject release];
	[super dealloc];
}

//---------------------------------------------------------------------------------------------
#pragma mark -


- (NSImage *) icon {
	return [self.sourceObject icon];
}


- (void) addChild:(PBGitMenuItem *)child {
	BOOL added = NO;
	for (PBGitMenuItem *item in self.children) {
		if ([[(id)child.sourceObject path] hasPrefix:[(id)[item sourceObject] path]]) {
			[item addChild:child];
			added = YES;
		}
	}
	if (!added) {
		[super addChild:child];
	}
}

- (void) expand {
	NSObject *item = self.parent;
	while (item && [item isKindOfClass:[PBGitMenuItem class]]) {
		[(id)item expand];
		item = [(id)item parent];
	}
}

@end
