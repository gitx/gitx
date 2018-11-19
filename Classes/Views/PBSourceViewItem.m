//
//  PBSourceViewItem.m
//  GitX
//
//  Created by Pieter de Bie on 9/8/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PBSourceViewItem.h"
#import "PBSourceViewItems.h"
#import "PBGitRef.h"

@interface PBSourceViewItem () {
	NSString *_title;
}

@property (nonatomic, strong) NSArray *sortedChildren;
@property (nonatomic, strong) NSMutableOrderedSet *childrenSet;

@end

@implementation PBSourceViewItem

+ (instancetype)itemWithTitle:(NSString *)title
{
	return [[[self class] alloc] initWithTitle:title revSpecifier:nil];
}

+ (instancetype)groupItemWithTitle:(NSString *)title
{
	PBSourceViewItem *item = [self itemWithTitle:[title uppercaseString]];
	item.groupItem = YES;
	return item;
}

+ (instancetype)itemWithRevSpec:(PBGitRevSpecifier *)revSpecifier
{
	PBGitRef *ref = [revSpecifier ref];

	if ([ref isTag])
		return [PBSourceViewGitTagItem tagItemWithRevSpec:revSpecifier];
	else if ([ref isBranch])
		return [PBSourceViewGitBranchItem branchItemWithRevSpec:revSpecifier];
	else if ([ref isRemoteBranch])
		return [PBSourceViewGitRemoteBranchItem remoteBranchItemWithRevSpec:revSpecifier];

	return [PBSourceViewOtherRevItem otherItemWithRevSpec:revSpecifier];
}

- (instancetype)initWithTitle:(NSString *)title revSpecifier:(PBGitRevSpecifier *)spec
{
	self = [super init];
	if (!self) return nil;

	_title = [title copy];
	_revSpecifier = [spec copy];
	_childrenSet = [[NSMutableOrderedSet alloc] init];
	return self;
}

- (instancetype)init
{
	NSAssert(NO, @"-init is not available");
	return nil;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@: %p title: %@ spec: %@>", self.className, self, self.title, self.revSpecifier];
}

- (NSArray *)sortedChildren
{
    if (!_sortedChildren) {
        NSArray *newArray = [_childrenSet sortedArrayUsingComparator:^NSComparisonResult(PBSourceViewItem *obj1, PBSourceViewItem *obj2) {
            return [obj1.title localizedStandardCompare:obj2.title];
        }];
		self.sortedChildren = newArray;
    }
    return [_sortedChildren copy];
}

- (void)addChild:(PBSourceViewItem *)child
{
	if (!child)
		return;
    
	[self.childrenSet addObject:child];
    self.sortedChildren = nil;
	child.parent = self;
}

- (void)removeChild:(PBSourceViewItem *)child
{
	if (!child)
		return;

	[self.childrenSet removeObject:child];
    self.sortedChildren = nil;
	if (!self.isGroupItem && ([self.childrenSet count] == 0))
		[self.parent removeChild:self];
}

- (void)addRev:(PBGitRevSpecifier *)theRevSpecifier toPath:(NSArray *)path
{
	if ([path count] == 1) {
		PBSourceViewItem *item = [PBSourceViewItem itemWithRevSpec:theRevSpecifier];
		[self addChild:item];
		return;
	}

	NSString *firstTitle = [path objectAtIndex:0];
	PBSourceViewItem *node = nil;
	for (PBSourceViewItem *child in self.childrenSet)
		if ([child.title isEqualToString:firstTitle])
			node = child;

	if (!node) {
		if ([firstTitle isEqualToString:[[theRevSpecifier ref] remoteName]])
			node = [PBSourceViewGitRemoteItem remoteItemWithTitle:firstTitle];
		else {
			node = [PBSourceViewFolderItem folderItemWithTitle:firstTitle];
            node.expanded = [[self title] isEqualToString:@"BRANCHES"];
        }
		[self addChild:node];
	}

	[node addRev:theRevSpecifier toPath:[path subarrayWithRange:NSMakeRange(1, [path count] - 1)]];
}

- (PBSourceViewItem *)findRev:(PBGitRevSpecifier *)rev
{
	if ([rev isEqual:self.revSpecifier])
		return self;

	PBSourceViewItem *item = nil;
	for (PBSourceViewItem *child in self.childrenSet)
		if ( (item = [child findRev:rev]) != nil )
			return item;

	return nil;
}

- (NSImage *)icon
{
	NSImage *iconImage = [NSImage imageNamed:self.iconName];
	[iconImage setSize:NSMakeSize(16,16)];
	[iconImage setCacheMode:NSImageCacheAlways];
	return iconImage;
}

- (NSString *)title
{
	if (_title)
		return _title;
	
	return [[self.revSpecifier description] lastPathComponent];
}

- (void)setTitle:(NSString *)title
{
	_title = [title copy];
}

- (NSString *)stringValue
{
	return self.title;
}

- (PBGitRef *)ref
{
	if (self.revSpecifier)
		return [self.revSpecifier ref];

	return nil;
}

@end
