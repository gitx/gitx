//
//  PBGitSVBranchItem.h
//  GitX
//
//  Created by Nathan Kinsinger on 3/2/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBSourceViewItem.h"


@interface PBGitSVBranchItem : PBSourceViewItem {
	BOOL isCheckedOut;
	NSNumber *behind;
	NSNumber *ahead;
}

+ (id)branchItemWithRevSpec:(PBGitRevSpecifier *)revSpecifier;

@property (assign) BOOL isCheckedOut;
@property (assign) NSNumber *behind;
@property (assign) NSNumber *ahead;

@end
