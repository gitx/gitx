//
//  PBArgumentPickerController.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBCommand.h"
#import "PBArgumentPicker.h"

@class PBCommandWithParameter;

@interface PBArgumentPickerController : NSWindowController {
	IBOutlet PBArgumentPicker *view;
	
	PBCommandWithParameter *cmdWithParameter;
}

- initWithCommandWithParameter:(PBCommandWithParameter *) command;

- (IBAction) okClicked:sender;
- (IBAction) cancelClicked:sender;
@end
