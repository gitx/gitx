//
//  PBCommandMenuItem.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBCommandMenuItem.h"

@interface PBCommandMenuItem()
@property (nonatomic, retain) PBCommand *command;
@end



@implementation PBCommandMenuItem
@synthesize command;

- initWithCommand:(PBCommand *) aCommand {
	if ((self = [super init])) {
		self.command = aCommand;
		super.title = [aCommand displayName];
		[self setTarget:aCommand];
		[self setAction:@selector(invoke)];
		[self setEnabled:[aCommand canBeFired]];
	}
	return self;
}

- (void) dealloc {
	[command release];
	[super dealloc];
}


@end
