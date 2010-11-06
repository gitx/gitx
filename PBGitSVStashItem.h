//
//  PBGitSVStashItem.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PBSourceViewItem.h"
#import "PBGitStash.h"


@interface PBGitSVStashItem : PBSourceViewItem {
	PBGitStash *stash;
}
@property (nonatomic, retain, readonly) PBGitStash *stash;

- initWithStash:(PBGitStash *) aStash;
@end
