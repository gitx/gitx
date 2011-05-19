//
//  PBGitSVRemoteItem.h
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBSourceViewItem.h"


@interface PBGitSVRemoteItem : PBSourceViewItem {
	BOOL alert;
	NSString *helpText;
}

@property (assign) BOOL alert;
@property (retain) NSString *helpText;

+ (id)remoteItemWithTitle:(NSString *)title;

@end
