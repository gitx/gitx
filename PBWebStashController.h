//
//  PBWebStashController.h
//
//  Created by David Catmull on 12-06-11.
//

#import <Cocoa/Cocoa.h>
#import "PBWebCommitController.h"

@class PBStashContentController;

@interface PBWebStashController : PBWebCommitController {
	IBOutlet PBStashContentController *stashController;
}

@end
