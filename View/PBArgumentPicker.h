//
//  PBArgumentPicker.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PBArgumentPicker : NSView {
	IBOutlet NSTextField *textField;
	IBOutlet NSTextField *label;
	IBOutlet NSButton *okButton;
	IBOutlet NSButton *cancelButton;
}
@property (nonatomic, retain, readonly) NSTextField *textField;
@property (nonatomic, retain, readonly) NSTextField *label;
@property (nonatomic, retain, readonly) NSButton *okButton;
@property (nonatomic, retain, readonly) NSButton *cancelButton;


@end
