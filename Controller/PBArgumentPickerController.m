//
//  PBArgumentPickerController.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBArgumentPickerController.h"
#import "PBCommandWithParameter.h"


@implementation PBArgumentPickerController

- initWithCommandWithParameter:(PBCommandWithParameter *) aCommand {
	if ((self = [super initWithWindowNibName:@"PBArgumentPicker" owner:self])) {
		cmdWithParameter = [aCommand retain];
	}
	return self;
}

- (void) dealloc {
	[cmdWithParameter release];

	[super dealloc];
}

- (void) awakeFromNib {
	NSString *stringToDisplay = [NSString stringWithFormat:@"%@:", [cmdWithParameter parameterDisplayName]];
	[view.label setTitleWithMnemonic:stringToDisplay];
}

- (IBAction) okClicked:sender {
	NSString *userText = [view.textField stringValue];
	if ([userText length] > 0) {
		NSString *paramName = [cmdWithParameter parameterName];
		[cmdWithParameter.command appendParameters:[NSArray arrayWithObjects:paramName, userText, nil]];
	}
	[self cancelClicked:sender];
	
	[cmdWithParameter.command invoke];
}

- (IBAction) cancelClicked:sender {
	[NSApp endSheet:[self window]];
	[[self window] orderOut:self];
}


@end
