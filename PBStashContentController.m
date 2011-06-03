//
//  PBStashContentController.h
//  GitX
//
//  Created by David Catmull on 20-06-11.
//  Copyright 2011. All rights reserved.
//

#import "PBStashContentController.h"
#import "PBGitStash.h"

@implementation PBStashContentController

- (void) awakeFromNib
{
}

- (void) showStash:(PBGitStash*)stash
{
  [webController changeContentTo:stash];
}

@end
