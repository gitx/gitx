//
//  PBCommand.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBCommand.h"


@implementation PBCommand
@synthesize displayName;
@synthesize parameters;
@synthesize commandDescription;
@synthesize commandTitle;

- (id) initWithDisplayName:(NSString *) aDisplayName parameters:(NSArray *) params {
	self = [super init];
	if (self != nil) {
		self.displayName = aDisplayName;
		parameters = [params retain];
		
		// default values
		self.commandTitle = @"";
		self.commandDescription = @"";
	}
	return self;
}


- (void) dealloc {
	[commandDescription release];
	[commandTitle release];
	[parameters release];
	[displayName release];
	[super dealloc];
}

- (void) invoke {
	NSLog(@"Warning: Empty/abstrac command has been fired!");
}

@end
