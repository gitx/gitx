//
//  PBCommandFactory.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBGitRepository.h"
#import "PBPresentable.h"

@protocol PBCommandFactory
+ (NSArray *) commandsForObject:(id<PBPresentable>) object repository:(PBGitRepository *) repository;
@end
