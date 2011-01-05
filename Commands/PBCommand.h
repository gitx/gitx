//
//  PBCommand.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PBGitRepository.h"

@interface PBCommand : NSObject {
	PBGitRepository *repository;
	
	// for the user to see what it triggers
	NSString *displayName;
	// shown during command execution
	NSString *commandTitle;
	NSString *commandDescription;
	
	NSMutableArray *parameters;
	BOOL canBeFired;
}
@property (nonatomic) BOOL canBeFired;
@property (nonatomic, retain, readonly) PBGitRepository *repository;
@property (nonatomic, retain) NSString *commandTitle;
@property (nonatomic, retain) NSString *commandDescription;
@property (nonatomic, copy) NSString *displayName;

- (id) initWithDisplayName:(NSString *) aDisplayName parameters:(NSArray *) params repository:(PBGitRepository *) repo;

- (void) invoke;

- (NSArray *) allParameters;
- (void) appendParameters:(NSArray *) params;
@end
