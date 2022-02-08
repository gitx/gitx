//
//  PBSourceViewGitStashItem.m
//  GitX
//
//  Created by Mathias Leppich on 8/1/13.
//
//

#import "PBSourceViewGitStashItem.h"
#import "PBGitRevSpecifier.h"

@interface PBSourceViewGitStashItem ()

@property (retain) PBGitStash *stash;

@end

@implementation PBSourceViewGitStashItem

+ (instancetype)itemWithStash:(PBGitStash *)stash
{
	return [[self alloc] initWithStash:stash];
}

- (instancetype)initWithStash:(PBGitStash *)stash
{
	NSString *title = [NSString stringWithFormat:@"@{%zd}: %@", stash.index, stash.message];
	PBGitRevSpecifier *spec = [[PBGitRevSpecifier alloc] initWithRef:stash.ref];

	self = [self initWithTitle:title revSpecifier:spec];
	if (!self) return nil;
	self.stash = stash;

	return self;
}

- (PBGitRef *)ref
{
	return self.stash.ref;
}

@end
