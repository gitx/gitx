//
//  PBStashCommand.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PBCommand.h"
#import "PBGitRepository.h"

@interface PBStashCommand : PBCommand {
	PBGitRepository *repository;
	NSArray *arguments;
}

- initWithDisplayName:(NSString *) aDisplayName arguments:(NSArray *) args repository:(PBGitRepository *) repo;
@end
