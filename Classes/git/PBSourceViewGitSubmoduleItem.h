//
//  PBSourceViewGitSubmoduleItem.h
//  GitX
//
//  Created by Seth Raphael on 9/14/12.
//
//

#import <Foundation/Foundation.h>
#import <ObjectiveGit/ObjectiveGit.h>
#import "PBSourceViewItem.h"


@interface PBSourceViewGitSubmoduleItem : PBSourceViewItem

+ (instancetype)itemWithSubmodule:(GTSubmodule *)submodule;

@property (nonatomic, readonly) GTSubmodule *submodule;
@property (nonatomic, readonly) NSURL *path;

@end
