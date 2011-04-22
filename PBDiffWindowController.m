//
//  PBDiffWindowController.m
//  GitX
//
//  Created by Pieter de Bie on 13-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBDiffWindowController.h"
#import "PBGitRepository.h"
#import "PBGitCommit.h"
#import "PBGitDefaults.h"
#import "GLFileView.h"


@implementation PBDiffWindowController
@synthesize diff;

- (id) initWithDiff:(NSString *)aDiff
{
	if (![super initWithWindowNibName:@"PBDiffWindow"])
		return nil;

	diff = aDiff;
    
	return self;
}


+ (void) showDiffWindowWithFiles:(NSArray *)filePaths fromCommit:(PBGitCommit *)startCommit diffCommit:(PBGitCommit *)diffCommit
{
	if (!startCommit)
		return;

	if (!diffCommit)
		diffCommit = [startCommit.repository headCommit];

	NSString *commitSelector = [NSString stringWithFormat:@"%@..%@", [startCommit realSha], [diffCommit realSha]];
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"diff", @"--no-ext-diff", commitSelector, nil];

	if (![PBGitDefaults showWhitespaceDifferences])
		[arguments insertObject:@"-w" atIndex:1];

	if (filePaths) {
		[arguments addObject:@"--"];
		[arguments addObjectsFromArray:filePaths];
	}

	int retValue;
	NSString *diff = [startCommit.repository outputInWorkdirForArguments:arguments retValue:&retValue];
	if (retValue) {
		DLog(@"diff failed with retValue: %d   for command: '%@'    output: '%@'", retValue, [arguments componentsJoinedByString:@" "], diff);
		return;
	}
    
    diff=[GLFileView parseDiff:diff];
    diff=[diff stringByReplacingOccurrencesOfString:@"{SHA_PREV}" withString:[startCommit realSha]];
    diff=[diff stringByReplacingOccurrencesOfString:@"{SHA}" withString:[diffCommit realSha]];

	PBDiffWindowController *diffController = [[PBDiffWindowController alloc] initWithDiff:diff];
	[diffController showWindow:nil];
}


@end
