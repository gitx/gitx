//
//  PBGitRevList.m
//  GitX
//
//  Created by Pieter de Bie on 17-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBGitRevList.h"
#import "PBGitRepository.h"
#import "PBGitCommit.h"
#import "PBGitGrapher.h"
#import "PBGitRevSpecifier.h"

#include <ext/stdio_filebuf.h>
#include <iostream>
#include <string>
#include <map>

using namespace std;


@interface PBGitRevList ()

@property (assign) BOOL isParsing;

@end


#define kRevListThreadKey @"thread"
#define kRevListRevisionsKey @"revisions"


@implementation PBGitRevList

@synthesize commits;
@synthesize isParsing;


- (id) initWithRepository:(PBGitRepository *)repo rev:(PBGitRevSpecifier *)rev shouldGraph:(BOOL)graph
{
	repository = repo;
	isGraphing = graph;
	currentRev = [rev copy];

	return self;
}


- (void) loadRevisons
{
	[parseThread cancel];

	parseThread = [[NSThread alloc] initWithTarget:self selector:@selector(walkRevisionListWithSpecifier:) object:currentRev];
	self.isParsing = YES;
	resetCommits = YES;
	[parseThread start];
}


- (void)cancel
{
	[parseThread cancel];
}


- (void) finishedParsing
{
	self.isParsing = NO;
}


- (void) updateCommits:(NSDictionary *)update
{
	if ([update objectForKey:kRevListThreadKey] != parseThread)
		return;

	NSArray *revisions = [update objectForKey:kRevListRevisionsKey];
	if (!revisions || [revisions count] == 0)
		return;

	if (resetCommits) {
		self.commits = [NSMutableArray array];
		resetCommits = NO;
	}

	NSRange range = NSMakeRange([commits count], [revisions count]);
	NSIndexSet *indexes = [NSIndexSet indexSetWithIndexesInRange:range];

	[self willChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"commits"];
	[commits addObjectsFromArray:revisions];
	[self didChange:NSKeyValueChangeInsertion valuesAtIndexes:indexes forKey:@"commits"];
}


- (void) walkRevisionListWithSpecifier:(PBGitRevSpecifier*)rev
{
	NSDate *start = [NSDate date];
	NSDate *lastUpdate = [NSDate date];
	NSMutableArray *revisions = [NSMutableArray array];
	PBGitGrapher *g = [[PBGitGrapher alloc] initWithRepository:repository];
	std::map<string, NSStringEncoding> encodingMap;
	NSThread *currentThread = [NSThread currentThread];

	NSString *formatString = @"--pretty=format:%H\01%e\01%aN\01%cN\01%P\01%at\01%s";
	BOOL showSign = [rev hasLeftRight];

	if (showSign)
		formatString = [@"%m\01" stringByAppendingString:formatString];
	
	NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"log", @"-z", @"--topo-order", @"--children", formatString, nil];

	if (!rev)
		[arguments addObject:@"HEAD"];
	else
		[arguments addObjectsFromArray:[rev parameters]];

	NSString *directory = rev.workingDirectory ? rev.workingDirectory.path : repository.fileURL.path;
	NSTask *task = [PBEasyPipe taskForCommand:[PBGitBinary path] withArgs:arguments inDir:directory];
	[task launch];
	NSFileHandle *handle = [task.standardOutput fileHandleForReading];
	
	int fd = [handle fileDescriptor];
	__gnu_cxx::stdio_filebuf<char> buf(fd, std::ios::in);
	std::istream stream(&buf);

	int num = 0;
	while (true) {
		if ([currentThread isCancelled])
			break;

        char c;
        char sign;
        if (showSign)
		{
			stream >> sign;
			stream >> c; // Remove separator
			if (sign != '>' && sign != '<' && sign != '^' && sign != '-')
				DLog(@"Error loading commits: sign not correct");
		}

		string sha;
		if (!getline(stream, sha, '\1'))
			break;

		// From now on, 1.2 seconds
		string encoding_str;
		getline(stream, encoding_str, '\1');
		NSStringEncoding encoding = NSUTF8StringEncoding;
		if (encoding_str.length())
		{
			if (encodingMap.find(encoding_str) != encodingMap.end()) {
				encoding = encodingMap[encoding_str];
			} else {
				encoding = CFStringConvertEncodingToNSStringEncoding(CFStringConvertIANACharSetNameToEncoding((CFStringRef)[NSString stringWithUTF8String:encoding_str.c_str()]));
				encodingMap[encoding_str] = encoding;
			}
		}

		git_oid oid;
		if(git_oid_mkstr(&oid, sha.c_str())!=GIT_SUCCESS)
            break;
        
		PBGitCommit *newCommit = [PBGitCommit commitWithRepository:repository andSha:[PBGitSHA shaWithOID:oid]];

        if (showSign)
            [newCommit setSign: sign];

		string author;
		getline(stream, author, '\1');

		string committer;
		getline(stream, committer, '\1');

		string parentString;
		getline(stream, parentString, '\1');
		if (parentString.size() != 0)
		{
			if (((parentString.size() + 1) % 41) != 0) {
				DLog(@"invalid parents: %zu", parentString.size());
				continue;
			}
			int nParents = (parentString.size() + 1) / 41;
			NSMutableArray *parents = [NSMutableArray arrayWithCapacity:nParents];
			int parentIndex;
			for (parentIndex = 0; parentIndex < nParents; ++parentIndex)
				[parents addObject:[PBGitSHA shaWithCString:parentString.substr(parentIndex * 41, 40).c_str()]];

			[newCommit setParents:parents];
		}

		int time;
		stream >> time;

        string subject;
		getline(stream, subject, '\0');
        
		[newCommit setSubject:[NSString stringWithCString:subject.c_str() encoding:encoding]];
		[newCommit setAuthor:[NSString stringWithCString:author.c_str() encoding:encoding]];
		[newCommit setCommitter:[NSString stringWithCString:committer.c_str() encoding:encoding]];
		[newCommit setTimestamp:time];
		
		[revisions addObject: newCommit];
		if (isGraphing)
			[g decorateCommit:newCommit];

		if (++num % 100 == 0) {
			if ([[NSDate date] timeIntervalSinceDate:lastUpdate] > 0.1) {
				NSDictionary *update = [NSDictionary dictionaryWithObjectsAndKeys:currentThread, kRevListThreadKey, revisions, kRevListRevisionsKey, nil];
				[self performSelectorOnMainThread:@selector(updateCommits:) withObject:update waitUntilDone:NO];
				revisions = [NSMutableArray array];
				lastUpdate = [NSDate date];
			}
		}
	}
	
	if (![currentThread isCancelled]) {
		NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:start];
		DLog(@"Loaded %i commits in %f seconds (%f/sec)", num, duration, num/duration);

		// Make sure the commits are stored before exiting.
		NSDictionary *update = [NSDictionary dictionaryWithObjectsAndKeys:currentThread, kRevListThreadKey, revisions, kRevListRevisionsKey, nil];
		[self performSelectorOnMainThread:@selector(updateCommits:) withObject:update waitUntilDone:YES];

		[self performSelectorOnMainThread:@selector(finishedParsing) withObject:nil waitUntilDone:NO];
	}
	else {
		DLog(@"[%@ %@] thread has been canceled", [self class], NSStringFromSelector(_cmd));
	}

	[task terminate];
	[task waitUntilExit];
}

@end
