//
//  PBGitTree.h
//  GitTest
//
//  Created by Pieter de Bie on 15-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PBGitRepository.h"

@interface PBGitTree : NSObject {
	long long _fileSize;
	
	NSString* sha;
	NSString* path;
	PBGitRepository* repository;
	__weak PBGitTree* parent;
	NSArray* children;
	BOOL leaf;
	
	NSString* localFileName;
	NSDate* localMtime;

	NSPredicate *filterPredicate;
	NSMutableArray *filteredChildren;
}

+ (PBGitTree*) rootForCommit: (id) commit;
+ (PBGitTree*) treeForTree: (PBGitTree*) tree andPath: (NSString*) path;
- (void) saveToFolder: (NSString *) directory;

- (NSString *) textContents:(NSError **)anError;
- (NSString *) blame:(NSError **)anError;
- (NSString *) log:(NSString *)format error:(NSError **)anError;
- (NSString *) diff:(NSString *)format error:(NSError **)anError;

- (NSString*) tmpFileNameForContents;
- (long long)fileSize;

@property(copy) NSString* sha;
@property(copy) NSString* path;
@property(assign) BOOL leaf;
@property(retain) PBGitRepository* repository;
@property(assign) __weak PBGitTree* parent;

@property (nonatomic, copy) NSPredicate *filterPredicate;
@property(readonly) NSArray *filteredChildren;

@property(readonly) NSArray* children;
@property(readonly) NSString* fullPath;
@property(readonly) NSString* contents;

@end
