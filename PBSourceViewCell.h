//
//  PBSourceViewCell.h
//  GitX
//
//  Created by Nathan Kinsinger on 1/7/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBIconAndTextCell.h"


@interface PBSourceViewCell : PBIconAndTextCell {
	BOOL isCheckedOut;
	NSNumber *behind;
	NSNumber *ahead;
	BOOL showsActionButton;
	
	BOOL iMouseDownInInfoButton;
    BOOL iMouseHoveredInInfoButton;
    SEL iInfoButtonAction;
}
@property (nonatomic) BOOL showsActionButton;
@property (nonatomic) SEL iInfoButtonAction;
@property (assign) BOOL isCheckedOut;
@property (assign) NSNumber *behind;
@property (assign) NSNumber *ahead;


@end
