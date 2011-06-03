//
//  PBStashViewController.h
//  GitX
//
//  Created by David Catmull on 20-06-11.
//  Copyright 2011. All rights reserved.
//

#import "PBStashViewController.h"
#import "PBGitStash.h"

@implementation PBStashViewController

- (void) awakeFromNib
{
}

- (void) showStash:(PBGitStash*)stash
{
  [webController changeContentTo:stash];
}

@end
