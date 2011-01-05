//
//  PBCommand.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PBCommand : NSObject {
	// for the user to see what it triggers
	NSString *displayName;
	// shown during command execution
	NSString *commandTitle;
	NSString *commandDescription;
	
	NSArray *parameters;
}
@property (nonatomic, retain) NSString *commandTitle;
@property (nonatomic, retain) NSString *commandDescription;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, retain, readonly) NSArray *parameters;

- (id) initWithDisplayName:(NSString *) aDisplayName parameters:(NSArray *) params;
- (void) invoke;
@end
