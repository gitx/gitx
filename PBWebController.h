//
//  PBWebController.h
//  GitX
//
//  Created by Pieter de Bie on 08-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

#import "PBGitRepository.h"

@interface PBWebController : NSObject {
	IBOutlet WebView* view;
	NSString *startFile;
	BOOL finishedLoading;

	// For async git reading
	NSMapTable *callbacks;

	// For the repository access
	IBOutlet PBGitRepository *repository;
}

@property (retain) NSString *startFile;
@property (retain) PBGitRepository *repository;

- (WebScriptObject *) script;
- (void) closeView;
- (BOOL) isFeatureEnabled:(NSString *)feature;

@end
