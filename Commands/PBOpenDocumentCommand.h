//
//  PBOpenDocumentCommand.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-07.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBCommand.h"

@interface PBOpenDocumentCommand : PBCommand {
	NSURL *documentURL;
}

- (id) initWithDocumentAbsolutePath:(NSString *) path;
@end
