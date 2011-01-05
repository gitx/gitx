//
//  PBSubmoduleController.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-27.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitSubmodule.h"

@class PBGitRepository;
@class PBCommand;

@interface PBSubmoduleController : NSObject {
	NSArray *submodules;
@private
	PBGitRepository *repository;
}
@property (nonatomic, retain, readonly) NSArray *submodules;

- (id) initWithRepository:(PBGitRepository *) repo;

- (void) reload;

- (NSArray *) menuItems;


// actions

- (void) addNewSubmodule;
- (void) initializeAllSubmodules;
- (void) updateAllSubmodules;

- (PBCommand *) commandForOpeningSubmodule:(PBGitSubmodule *) submodule;
- (PBCommand *) defaultCommandForSubmodule:(PBGitSubmodule *) submodule;
@end
