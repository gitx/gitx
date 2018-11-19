//
//  PBSourceViewGitStashItem.h
//  GitX
//
//  Created by Mathias Leppich on 8/1/13.
//
//

#import <Cocoa/Cocoa.h>
#import "PBSourceViewItem.h"
#import "PBGitStash.h"

@interface PBSourceViewGitStashItem : PBSourceViewItem

+ (instancetype)itemWithStash:(PBGitStash *)stash;

@property (nonatomic, readonly) PBGitStash *stash;

@end
