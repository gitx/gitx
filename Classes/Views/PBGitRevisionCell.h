//
//  PBGitRevisionCell.h
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitGrapher.h"
#import "PBGraphCellInfo.h"
#import "PBGitHistoryController.h"
#import "PBRefContextDelegate.h"

@interface PBGitRevisionCell : NSTableCellView {
	PBGitCommit *objectValue;
	PBGraphCellInfo *cellInfo;
	__weak IBOutlet PBGitHistoryController *controller;
	__weak IBOutlet NSLayoutConstraint *leftMarginTextConstraint;
}

- (int) indexAtX:(CGFloat)x;
- (NSRect) rectAtIndex:(int)index;
- (void) drawLabelAtIndex:(int)index inRect:(NSRect)rect;

@property (copy) PBGitCommit* objectValue;
@end
