//
//  PBSourceViewGitSubmoduleItem.m
//  GitX
//
//  Created by Seth Raphael on 9/14/12.
//
//

#import "PBSourceViewGitSubmoduleItem.h"
#import <ObjectiveGit/ObjectiveGit.h>

@interface PBSourceViewGitSubmoduleItem ()

@property (nonatomic, retain) GTSubmodule *submodule;

@end

@implementation PBSourceViewGitSubmoduleItem

+ (instancetype)itemWithSubmodule:(GTSubmodule *)submodule
{
	return [[self alloc] initWithSubmodule:submodule];
}

- (instancetype)initWithSubmodule:(GTSubmodule *)submodule
{
	self = [self initWithTitle:submodule.name revSpecifier:nil];
	if (!self) return nil;

	_submodule = submodule;

	return self;
}

- (NSString *)title
{
	return self.submodule.name;
}

- (NSURL *)path
{
	NSURL *parentURL = self.submodule.parentRepository.fileURL;
	NSURL *result = [parentURL URLByAppendingPathComponent:self.submodule.path];
	return result;
}
@end
