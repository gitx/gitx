//
//  PBGitConfig.h
//  GitX
//
//  Created by Pieter de Bie on 14-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitBinary.h"
#import "PBEasyPipe.h"

@interface PBGitConfig : NSObject {
	NSString *repositoryPath;
}

- init;
- initWithRepositoryPath:(NSString *)path;

// get config data: `git config -l`
- (NSDictionary*) listConfigValuesInDir:(NSString*)inDir;

@end
