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
static const NSTimeInterval PBGitRepositoryWatcherDefaultMaxCoalesceInterval = 1.5;

@interface PBGitRepositoryWatcher () {
	FSEventStreamRef eventStream;
	BOOL _running;
	NSUInteger _coalesceGeneration;
	NSDate *_coalesceStartedAt;
}

@property (readonly) NSString *gitDir;
@property (readonly) NSString *workDir;
@property (nonatomic) NSTimeInterval coalesceInterval;
@property (nonatomic) NSTimeInterval maxCoalesceInterval;

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
	(void)numEvents;

	// Paths are not git semantics. With FileEvents they name the file that
	// moved, so .lock and objects/ churn can be dropped without reading git.
	PBGitRepositoryWatcher *watcher = (__bridge PBGitRepositoryWatcher *)clientCallBackInfo;
	NSArray *eventPaths = (__bridge NSArray *)_eventPaths;
	if (![watcher eventPathsContainInterestingChange:eventPaths])
		return;

	// The stream is on the main queue, so this is already the UI thread.
	[watcher noteDiskChanged];
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
	_maxCoalesceInterval = PBGitRepositoryWatcherDefaultMaxCoalesceInterval;

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
	// FileEvents so paths name files (index.lock) rather than only the folder.
	eventStream = FSEventStreamCreate(kCFAllocatorDefault, PBGitRepositoryWatcherCallback, &context,
									  (__bridge CFArrayRef)array,
									  kFSEventStreamEventIdSinceNow, 0.1,
									  kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagIgnoreSelf | kFSEventStreamCreateFlagFileEvents);
}

- (void)start
{
	if (_running)
		return;

	[self _initializeStream];
	if (!eventStream)
		return;

	FSEventStreamSetDispatchQueue(eventStream, dispatch_get_main_queue());
	FSEventStreamStart(eventStream);

	_running = YES;
}

- (void)stop
{
	_coalesceGeneration++;
	_coalesceStartedAt = nil;

	if (!_running)
		return;

	if (eventStream) {
		FSEventStreamStop(eventStream);
		FSEventStreamSetDispatchQueue(eventStream, NULL);
	}

	_running = NO;
}

- (void)noteDiskChanged
{
	NSDate *now = [NSDate date];
	if (!_coalesceStartedAt)
		_coalesceStartedAt = now;

	_coalesceGeneration++;
	NSUInteger generation = _coalesceGeneration;

	if (self.coalesceInterval <= 0) {
		_coalesceStartedAt = nil;
		[self syncRepository];
		return;
	}

	// Quiet period after the last event, but never wait longer than the max
	// once the first event of a burst arrived — a watch-mode build must not
	// starve a terminal commit forever.
	NSTimeInterval sinceStart = [now timeIntervalSinceDate:_coalesceStartedAt];
	NSTimeInterval delay = self.coalesceInterval;
	if (self.maxCoalesceInterval > 0 && sinceStart + delay > self.maxCoalesceInterval)
		delay = MAX(0, self.maxCoalesceInterval - sinceStart);

	__weak typeof(self) weakSelf = self;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
				   dispatch_get_main_queue(), ^{
					   PBGitRepositoryWatcher *watcher = weakSelf;
					   if (!watcher || watcher->_coalesceGeneration != generation)
						   return;
					   watcher->_coalesceStartedAt = nil;
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
