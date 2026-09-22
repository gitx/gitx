//
//  PBGitRepositoryWatcher.m
//  GitX
//
//  Created by Dave Grijalva on 1/26/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//
#import <CoreServices/CoreServices.h>

#import "PBGitRepositoryWatcher.h"
#import "PBGitRepository.h"
#import "PBGitDefaults.h"

static const NSTimeInterval PBGitRepositoryWatcherDefaultCoalesceInterval = 0.35;

@interface PBGitRepositoryWatcher () {
	FSEventStreamRef eventStream;
	BOOL _running;
}

@property (readonly) NSString *gitDir;
@property (readonly) NSString *workDir;
@property (nonatomic) NSTimeInterval coalesceInterval;

@end

void PBGitRepositoryWatcherCallback(ConstFSEventStreamRef streamRef,
									void *clientCallBackInfo,
									size_t numEvents,
									void *_eventPaths,
									const FSEventStreamEventFlags eventFlags[],
									const FSEventStreamEventId eventIds[])
{
	(void)streamRef;
	(void)numEvents;
	(void)_eventPaths;
	(void)eventFlags;
	(void)eventIds;

	// Paths and flags are not git. Any event under the stream roots means the
	// repository on disk may have moved; the repository then reads git.
	PBGitRepositoryWatcher *watcher = (__bridge PBGitRepositoryWatcher *)clientCallBackInfo;
	void (^note)(void) = ^{
		[watcher noteDiskChanged];
	};

	if ([NSThread isMainThread])
		note();
	else
		dispatch_async(dispatch_get_main_queue(), note);
}

@implementation PBGitRepositoryWatcher

- (instancetype)initWithRepository:(PBGitRepository *)theRepository
{
	NSParameterAssert(theRepository != nil);

	self = [super init];
	if (!self) {
		return nil;
	}

	_repository = theRepository;
	_coalesceInterval = PBGitRepositoryWatcherDefaultCoalesceInterval;

	if ([PBGitDefaults useRepositoryWatcher])
		[self start];
	return self;
}

- (void)dealloc
{
	[self stop];
	if (eventStream) {
		FSEventStreamInvalidate(eventStream);
		FSEventStreamRelease(eventStream);
		eventStream = NULL;
	}
}

- (NSString *)gitDir
{
	return [self.repository.gtRepo.gitDirectoryURL.path stringByStandardizingPath];
}

- (NSString *)workDir
{
	return !self.repository.gtRepo.isBare ? [self.repository.gtRepo.fileURL.path stringByStandardizingPath] : nil;
}

- (void)_initializeStream
{
	if (eventStream)
		return;

	NSMutableArray *array = [NSMutableArray array];
	if (self.gitDir)
		[array addObject:self.gitDir];
	if (self.workDir)
		[array addObject:self.workDir];

	if (!array.count)
		return;

	FSEventStreamContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};
	eventStream = FSEventStreamCreate(kCFAllocatorDefault, PBGitRepositoryWatcherCallback, &context,
									  (__bridge CFArrayRef)array,
									  kFSEventStreamEventIdSinceNow, 0.1,
									  kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagIgnoreSelf);
}

- (void)start
{
	if (_running)
		return;

	[self _initializeStream];
	if (!eventStream)
		return;

	FSEventStreamScheduleWithRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamStart(eventStream);

	_running = YES;
}

- (void)stop
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncRepository) object:nil];

	if (!_running)
		return;

	if (eventStream) {
		FSEventStreamStop(eventStream);
		FSEventStreamUnscheduleFromRunLoop(eventStream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}

	_running = NO;
}

- (void)noteDiskChanged
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(syncRepository) object:nil];

	if (self.coalesceInterval <= 0) {
		[self syncRepository];
		return;
	}

	[self performSelector:@selector(syncRepository) withObject:nil afterDelay:self.coalesceInterval];
}

- (void)syncRepository
{
	[self.repository syncWithWorkingTree];
}

@end
