//
//  PBWebHistoryController.m
//  GitTest
//
//  Created by Pieter de Bie on 14-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBWebHistoryController.h"
#import "PBGitDefaults.h"
#import "PBGitHistoryController.h"

@implementation PBWebHistoryController

- (void) awakeFromNib
{
	startFile = @"history";
	repository = historyController.repository;
	[super awakeFromNib];
	[historyController addObserver:self forKeyPath:@"webCommit" options:0 context:@"ChangedCommit"];
}

- (void)closeView
{
	[[self script] setValue:nil forKey:@"commit"];
	[historyController removeObserver:self forKeyPath:@"webCommit"];
	
	[super closeView];
}

- (void) didLoad
{
	[super didLoad];
	[self changeContentTo: historyController.webCommit];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([(NSString *)context isEqualToString: @"ChangedCommit"])
		[self changeContentTo: historyController.webCommit];
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (NSString*) refsForCurrentCommit
{
	NSMutableString *refs = [NSMutableString string];
	NSArray *refsA = [historyController.webCommit refs];
	NSString *currentRef = [[[historyController repository] headRef] simpleRef];
	NSString *style = @"";
	for(PBGitRef *ref in refsA){
		if([currentRef isEqualToString:[ref ref]]){
			style = [NSString stringWithFormat:@"currentBranch refs %@",[ref type]];
		}else{
			style = [NSString stringWithFormat:@"refs %@",[ref type]];
		}
		[refs appendString:[NSString stringWithFormat:@"<span class='%@'>%@</span>",style,[ref shortName]]];
	}
	
	return refs;
}

- (void)selectCommit:(NSString *)sha
{
	[historyController selectCommit:sha];
}

- (PBGitRef*) refFromString:(NSString*)refString
{
	for (PBGitRef *ref in historyController.webCommit.refs)
		if ([[ref shortName] isEqualToString:refString])
			return ref;
	return nil;
}

- (NSArray*) menuItemsForPath:(NSString*)path
{
	return [historyController menuItemsForPaths:[NSArray arrayWithObject:path]];
}

@end
