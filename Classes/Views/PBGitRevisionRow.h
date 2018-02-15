//
//  PBGitRevisionRow.h
//  GitX
//
//  Created by Max Langer on 18.01.18.
//

#import <Cocoa/Cocoa.h>

#import "PBGitHistoryController.h"

NS_ASSUME_NONNULL_BEGIN

@interface PBGitRevisionRow : NSTableRowView

@property (weak) PBGitHistoryController *controller;

@end

NS_ASSUME_NONNULL_END
