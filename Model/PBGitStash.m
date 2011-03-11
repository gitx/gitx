//
//  PBGitStash.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBGitStash.h"


@implementation PBGitStash
@synthesize name;
@synthesize message;
@synthesize stashRawString;
@synthesize stashSourceMessage;

- initWithRawStashLine:(NSString *) stashLineFromStashListOutput {
	if ((self = [super init])) {
		stashRawString = [stashLineFromStashListOutput retain];
		NSArray *lineComponents = [stashLineFromStashListOutput componentsSeparatedByString:@":"];
		name = [[lineComponents objectAtIndex:0] retain];
		stashSourceMessage = [[[lineComponents objectAtIndex:1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] retain];
		message = [[[lineComponents objectAtIndex:2] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] retain];
	}
	return self;
}

- (void) dealloc {
	[stashSourceMessage release];
	[stashRawString release];
	[name release];
	[message release];
	[super dealloc];
}

- (NSString *) description {
	return self.stashRawString;
}

#pragma mark Presentable

- (NSString *) displayDescription {
	return [NSString stringWithFormat:@"%@ (%@)", self.message, self.name];
}

- (NSString *) popupDescription {
	return [self description];
}

- (NSImage *) icon {
	return [NSImage imageNamed:@"stash-icon.png"];
}

@end
