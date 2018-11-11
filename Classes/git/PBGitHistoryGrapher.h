//
//  PBGitHistoryGrapher.h
//  GitX
//
//  Created by Nathan Kinsinger on 2/20/10.
//  Copyright 2010 Nathan Kinsinger. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define kCurrentQueueKey @"kCurrentQueueKey"
#define kNewCommitsKey @"kNewCommitsKey"


@class PBGitGrapher;

@protocol PBGitHistoryGrapherDelegate <NSObject>
- (void)updateCommitsFromGrapher:(NSDictionary *)commitData;
- (void)finishedGraphing;
@end


@interface PBGitHistoryGrapher : NSObject {
	__weak id <PBGitHistoryGrapherDelegate> delegate;
	NSOperationQueue *currentQueue;

	NSMutableSet *searchOIDs;
	PBGitGrapher *grapher;
	BOOL viewAllBranches;
}

- (instancetype) initWithBaseCommits:(NSSet *)commits viewAllBranches:(BOOL)viewAll queue:(NSOperationQueue *)queue delegate:(id <PBGitHistoryGrapherDelegate>)theDelegate;
- (void) graphCommits:(NSArray *)revList;

@end
