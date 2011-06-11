//
//  PBWebHistoryController.h
//  GitTest
//
//  Created by Pieter de Bie on 14-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBWebCommitController.h"

@class PBGitHistoryController;

@class NSString;

@interface PBWebHistoryController : PBWebCommitController {
	IBOutlet PBGitHistoryController* historyController;
}

@end
