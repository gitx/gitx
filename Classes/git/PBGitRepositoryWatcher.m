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
#import "PBGitIndex.h"
#import "PBGitDefaults.h"

static const NSTimeInterval PBGitRepositoryWatcherDefaultCoalesceInterval = 0.35;

@interface PBGitRepositoryWatcher () {
	FSEventStreamRef eventStream;
	BOOL _running;
	NSUInteger _coalesceGeneration;
}

@property (readonly) NSString *gitDir;
@property (readonly) NSString *workDir;
@property (nonatomic) NSTimeInterval coalesceInterval;

- (void)noteDiskChanged;
- (BOOL)eventPathsContainInterestingChange:(NSArray *)eventPaths;

@end

void PBGitRepositoryWatcherCallback(ConstFSEventStreamRef streamRef,
									void *clientCallBackInfo,
									size_t numEvents,
									void *_eventPaths,
									const FSEventStreamEventFlags eventFlags[],
									const FSEventStreamEventId eventIds[])
{
	(void)streamRef;
	(void)eventFlags;
	(void)eventIds;

	// Paths are not git semantics. They only decide whether the disk note is
	// noise (.lock churn from a git subprocess, or pack files under objects/)
	// or a real change the repository should read.
	PBGitRepositoryWatcher *watcher = (__bridge PBGitRepositoryWatcher *)clientCallBackInfo;
	NSArray *eventPaths = (__bridge NSArray *)_eventPaths;
	if (numEvents == 0 || ![watcher eventPathsContainInterestingChange:eventPaths])
		return;

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

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(applicationDidBecomeActive:)
												 name:NSApplicationDidBecomeActiveNotification
											   object:nil];

	if ([PBGitDefaults useRepositoryWatcher])
		[self start];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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

- (NSString *)objectsDir
{
	NSString *gitDir = self.gitDir;
	return gitDir ? [gitDir stringByAppendingPathComponent:@"objects"] : nil;
}

// Lock files are written by git subprocesses GitX launches. IgnoreSelf only
// covers this process, so without this a sync would feed itself through
// index.lock. Pack churn under objects/ is not a reason to re-read refs.
- (BOOL)eventPathsContainInterestingChange:(NSArray *)eventPaths
{
	NSString *objectsDir = self.objectsDir;

	for (NSString *rawPath in eventPaths) {
		NSString *path = [rawPath stringByStandardizingPath];
		if ([path hasSuffix:@".lock"])
			continue;
		if (objectsDir && [path hasPrefix:objectsDir])
			continue;
		return YES;
	}

	return NO;
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
	_coalesceGeneration++;

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
	_coalesceGeneration++;
	NSUInteger generation = _coalesceGeneration;

	if (self.coalesceInterval <= 0) {
		[self syncRepository];
		return;
	}

	// Main-queue afterDelay still runs while a menu or a drag is tracking,
	// unlike performSelector:afterDelay: which stays in the default mode.
	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.coalesceInterval * NSEC_PER_SEC)),
				   dispatch_get_main_queue(), ^{
					   PBGitRepositoryWatcher *watcher = weakSelf;
					   if (!watcher || watcher->_coalesceGeneration != generation)
						   return;
					   [watcher syncRepository];
				   });
}

- (void)syncRepository
{
	[self.repository syncWithWorkingTree];
}

// update-index --refresh holds index.lock, so it stays off the FSEvents path
// (#164). Become-active is enough to clear phantom mtime-only "modified" rows.
- (void)applicationDidBecomeActive:(NSNotification *)notification
{
	(void)notification;
	[self.repository.index refreshStatCache];
}

@end
