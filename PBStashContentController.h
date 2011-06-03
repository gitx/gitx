//
//  PBStashContentController.h
//  GitX
//
//  Created by David Catmull on 20-06-11.
//  Copyright 2011. All rights reserved.
//

#import "PBViewController.h"
#import "PBWebHistoryController.h"

@class PBGitStash;
@class PBWebStashController;

// Controls the view displaying a stash diff
@interface PBStashContentController : PBViewController {
	IBOutlet id webView;
	IBOutlet PBWebStashController *webController;
}

- (void) showStash:(PBGitStash*)stash;

@end

// TODO: This class may not be needed
@interface PBWebStashController : PBWebHistoryController {
}

@end
