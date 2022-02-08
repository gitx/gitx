//
//  PBGitGrapher.h
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

@class PBGitCommit;

@interface PBGitGrapher : NSObject

- (void)decorateCommit:(PBGitCommit *)commit;

@end
