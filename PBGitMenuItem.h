//
//  PBGitSVStashItem.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-05.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PBSourceViewItem.h"
#import "PBPresentable.h"


@interface PBGitMenuItem : PBSourceViewItem {
	id<PBPresentable> sourceObject;
}
@property (nonatomic, retain, readonly) id<PBPresentable> sourceObject;

- initWithSourceObject:(id<PBPresentable>) anObject;
@end
