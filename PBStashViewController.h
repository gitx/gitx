//
//  PBStashViewController.h
//  GitX
//
//  Created by David Catmull on 20-06-11.
//  Copyright 2011. All rights reserved.
//

#import "PBViewController.h"
#import "PBWebController.h"

@class PBGitStash;
@class PBWebStashController;

// Controls the view displaying a stash diff
@interface PBStashViewController : PBViewController {
	IBOutlet id webView;
	IBOutlet PBWebStashController *webController;
}

- (void) showStash:(PBGitStash*)stash;

@end

@interface PBWebStashController : PBWebController {
	PBGitStash* currentStash;
	NSString* diff;
}

- (void) changeContentTo:(PBGitStash*)stash;

@property (readonly) NSString* diff;

@end
