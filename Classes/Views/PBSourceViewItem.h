//
//  PBSourceViewItem.h
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PBGitRevSpecifier;
@class PBGitRef;

NS_ASSUME_NONNULL_BEGIN

@interface PBSourceViewItem : NSObject

+ (instancetype)groupItemWithTitle:(NSString *)title;
+ (instancetype)itemWithRevSpec:(PBGitRevSpecifier *)revSpecifier;
+ (instancetype)itemWithTitle:(NSString *)title;

- (instancetype)initWithTitle:(NSString *)title revSpecifier:(nullable PBGitRevSpecifier *)spec NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

- (void)addChild:(PBSourceViewItem *)child;
- (void)removeChild:(PBSourceViewItem *)child;

// This adds the ref to the path, which should match the item's title,
// so "refs/heads/pu/pb/sidebar" would have the path [@"pu", @"pb", @"sidebare"]
// to the 'local' branch thing
- (void)addRev:(PBGitRevSpecifier *)revSpecifier toPath:(NSArray *)path;
- (nullable PBSourceViewItem *)findRev:(PBGitRevSpecifier *)rev;

- (nullable PBGitRef *)ref;

@property (readonly) NSString *title;
@property (readonly) NSArray *sortedChildren;
@property (getter=isGroupItem) BOOL groupItem;
@property (getter=isUncollapsible) BOOL uncollapsible;
@property (getter=isExpanded) BOOL expanded;
@property PBGitRevSpecifier *revSpecifier;
@property PBSourceViewItem *parent;
@property (readonly) NSString *iconName;
@property (nullable, readonly) NSImage *icon;

@end

NS_ASSUME_NONNULL_END
