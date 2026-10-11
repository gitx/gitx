//
//  PBGitWorktree.m
//  GitX
//

#import "PBGitWorktree.h"

NS_ASSUME_NONNULL_BEGIN

@interface PBGitWorktree ()

@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy, nullable) NSString *HEAD;
@property (nonatomic, copy, nullable) NSString *branchRefName;
@property (nonatomic, assign, getter=isBare) BOOL bare;
@property (nonatomic, assign, getter=isDetached) BOOL detached;
@property (nonatomic, assign, getter=isCurrent) BOOL current;
@property (nonatomic, assign, getter=isMain) BOOL main;
@property (nonatomic, assign, getter=isLocked) BOOL locked;
@property (nonatomic, copy, nullable) NSString *lockReason;
@property (nonatomic, assign, getter=isPrunable) BOOL prunable;
@property (nonatomic, copy, nullable) NSString *prunableReason;
@property (nonatomic, assign) PBGitWorktreeLinkStyle linkStyle;
@property (nonatomic, assign, getter=hasBrokenLink) BOOL brokenLink;
@property (nonatomic, copy, nullable) NSString *movedPath;

@end

@implementation PBGitWorktree

// git quotes a reason that carries unusual characters the way core.quotePath
// describes, so the value cannot be taken as it stands.
+ (NSString *)reasonFromValue:(NSString *)value
{
	if (value.length < 2 || ![value hasPrefix:@"\""] || ![value hasSuffix:@"\""])
		return value;

	// The escapes stand for bytes of the UTF-8 encoding, so they are gathered as
	// bytes and decoded once at the end rather than one character at a time.
	NSString *body = [value substringWithRange:NSMakeRange(1, value.length - 2)];
	const char *encoded = body.UTF8String;
	NSUInteger length = strlen(encoded);
	NSMutableData *bytes = [NSMutableData dataWithCapacity:length];
	NSUInteger index = 0;

	while (index < length) {
		unsigned char character = (unsigned char)encoded[index++];

		if (character != '\\' || index >= length) {
			[bytes appendBytes:&character length:1];
			continue;
		}

		unsigned char escaped = (unsigned char)encoded[index++];

		if (escaped >= '0' && escaped <= '7') {
			unsigned octal = escaped - '0';
			for (int digits = 0; digits < 2 && index < length && encoded[index] >= '0' && encoded[index] <= '7'; digits++)
				octal = octal * 8 + (unsigned)(encoded[index++] - '0');

			unsigned char byte = (unsigned char)octal;
			[bytes appendBytes:&byte length:1];
			continue;
		}

		switch (escaped) {
			case 'n': escaped = '\n'; break;
			case 't': escaped = '\t'; break;
			case 'r': escaped = '\r'; break;
			case 'f': escaped = 0x0C; break;
			case 'v': escaped = 0x0B; break;
			case 'b': escaped = 0x08; break;
			case 'a': escaped = 0x07; break;
			default: break;
		}

		[bytes appendBytes:&escaped length:1];
	}

	return [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding] ?: value;
}


+ (NSArray<PBGitWorktree *> *)worktreesFromPorcelain:(NSString *)porcelain currentWorktreeAtPath:(nullable NSString *)currentPath
{
	NSMutableArray<PBGitWorktree *> *worktrees = [NSMutableArray array];
	NSString *standardizedCurrent = currentPath.stringByStandardizingPath;
	PBGitWorktree *worktree = nil;

	for (NSString *line in [porcelain componentsSeparatedByString:@"\n"]) {
		if ([line hasPrefix:@"worktree "]) {
			worktree = [[PBGitWorktree alloc] init];
			worktree.path = [line substringFromIndex:[@"worktree " length]];
			worktree.current = standardizedCurrent && [worktree.path.stringByStandardizingPath isEqualToString:standardizedCurrent];
			worktree.main = worktrees.count == 0;
			[worktrees addObject:worktree];
			continue;
		}

		if (!worktree)
			continue;

		if (line.length == 0) {
			worktree = nil;
		} else if ([line isEqualToString:@"bare"]) {
			worktree.bare = YES;
		} else if ([line isEqualToString:@"detached"]) {
			worktree.detached = YES;
		} else if ([line hasPrefix:@"HEAD "]) {
			worktree.HEAD = [line substringFromIndex:[@"HEAD " length]];
		} else if ([line hasPrefix:@"branch "]) {
			worktree.branchRefName = [line substringFromIndex:[@"branch " length]];
		} else if ([line isEqualToString:@"locked"]) {
			worktree.locked = YES;
		} else if ([line hasPrefix:@"locked "]) {
			worktree.locked = YES;
			worktree.lockReason = [self reasonFromValue:[line substringFromIndex:[@"locked " length]]];
		} else if ([line isEqualToString:@"prunable"]) {
			worktree.prunable = YES;
		} else if ([line hasPrefix:@"prunable "]) {
			worktree.prunable = YES;
			worktree.prunableReason = [self reasonFromValue:[line substringFromIndex:[@"prunable " length]]];
		}
	}

	return worktrees;
}

// A path that is gone cannot be resolved as a whole, so the part of it that
// is still there is, which keeps /var and /private/var from differing.
+ (NSString *)canonicalPath:(NSString *)path
{
	NSString *standardized = path.stringByStandardizingPath;
	NSString *existing = standardized;
	NSMutableArray<NSString *> *missing = [NSMutableArray array];

	while (existing.length > 1 && ![[NSFileManager defaultManager] fileExistsAtPath:existing]) {
		[missing insertObject:existing.lastPathComponent atIndex:0];
		existing = existing.stringByDeletingLastPathComponent;
	}

	char resolved[PATH_MAX];
	NSString *base = realpath(existing.fileSystemRepresentation, resolved) ? [NSString stringWithUTF8String:resolved] : existing;

	return missing.count ? [base stringByAppendingPathComponent:[NSString pathWithComponents:missing]] : base;
}

+ (nullable NSString *)firstLineOfFileAtPath:(NSString *)path
{
	NSString *contents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];

	return [contents componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]].firstObject;
}

// A worktree's .git file holds "gitdir: <path>", relative to the worktree when
// it was made with --relative-paths.
+ (nullable NSString *)linkTargetOfWorktreeAtPath:(NSString *)worktreePath style:(PBGitWorktreeLinkStyle *)style
{
	NSString *dotGit = [worktreePath stringByAppendingPathComponent:@".git"];
	BOOL isDirectory = NO;
	if (![[NSFileManager defaultManager] fileExistsAtPath:dotGit isDirectory:&isDirectory] || isDirectory)
		return nil;

	NSString *line = [self firstLineOfFileAtPath:dotGit];
	if (![line hasPrefix:@"gitdir: "])
		return nil;

	NSString *target = [line substringFromIndex:[@"gitdir: " length]];
	*style = target.isAbsolutePath ? PBGitWorktreeLinkStyleAbsolute : PBGitWorktreeLinkStyleRelative;

	return target.isAbsolutePath ? target.stringByStandardizingPath : [worktreePath stringByAppendingPathComponent:target].stringByStandardizingPath;
}

// Each worktrees/<id>/gitdir names the worktree's .git file, which is how git
// itself ties a listed path to its administrative folder.
+ (NSDictionary<NSString *, NSString *> *)idsByWorktreePathInCommonDirectory:(NSString *)commonDirectory
{
	NSString *administrative = [commonDirectory stringByAppendingPathComponent:@"worktrees"];
	NSMutableDictionary<NSString *, NSString *> *ids = [NSMutableDictionary dictionary];

	for (NSString *identifier in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:administrative error:NULL]) {
		NSString *folder = [administrative stringByAppendingPathComponent:identifier];
		NSString *dotGit = [self firstLineOfFileAtPath:[folder stringByAppendingPathComponent:@"gitdir"]];
		if (!dotGit.length)
			continue;

		if (!dotGit.isAbsolutePath)
			dotGit = [folder stringByAppendingPathComponent:dotGit];

		ids[[self canonicalPath:dotGit.stringByDeletingLastPathComponent]] = identifier;
	}

	return ids;
}

// A worktree nested in the main folder moved along with it, so its folder is
// the old path with the old main folder swapped for the new one. Its .git file
// still names the old main folder, which says where that boundary is.
+ (nullable NSString *)movedPathOfWorktree:(PBGitWorktree *)worktree identifier:(NSString *)identifier mainPath:(NSString *)mainPath commonDirectory:(NSString *)commonDirectory style:(PBGitWorktreeLinkStyle *)style
{
	NSString *main = [self canonicalPath:mainPath];
	NSString *common = [self canonicalPath:commonDirectory];
	NSString *commonInsideMain = nil;

	if ([common isEqualToString:main])
		commonInsideMain = @"";
	else if ([common hasPrefix:[main stringByAppendingString:@"/"]])
		commonInsideMain = [common substringFromIndex:main.length + 1];
	else
		return nil;

	NSString *path = worktree.path.stringByStandardizingPath;
	for (NSString *formerMain = path.stringByDeletingLastPathComponent; formerMain.length > 1; formerMain = formerMain.stringByDeletingLastPathComponent) {
		NSString *candidate = [mainPath stringByAppendingPathComponent:[path substringFromIndex:formerMain.length + 1]];
		PBGitWorktreeLinkStyle candidateStyle = PBGitWorktreeLinkStyleUnknown;
		NSString *target = [self linkTargetOfWorktreeAtPath:candidate style:&candidateStyle];
		NSString *formerAdministrative = [[[formerMain stringByAppendingPathComponent:commonInsideMain] stringByAppendingPathComponent:@"worktrees"] stringByAppendingPathComponent:identifier].stringByStandardizingPath;

		if (![target isEqualToString:formerAdministrative] || [[NSFileManager defaultManager] fileExistsAtPath:target])
			continue;

		*style = candidateStyle;
		return candidate;
	}

	return nil;
}

+ (void)checkLinksOfWorktrees:(NSArray<PBGitWorktree *> *)worktrees commonDirectory:(NSString *)commonDirectory
{
	NSDictionary<NSString *, NSString *> *ids = [self idsByWorktreePathInCommonDirectory:commonDirectory];
	PBGitWorktree *main = worktrees.firstObject.isMain ? worktrees.firstObject : nil;

	for (PBGitWorktree *worktree in worktrees) {
		if (worktree.isMain)
			continue;

		NSString *identifier = ids[[self canonicalPath:worktree.path]];
		if (!identifier) {
			NSLog(@"No administrative folder names the worktree at %@, so its link is not checked", worktree.path);
			continue;
		}

		PBGitWorktreeLinkStyle style = PBGitWorktreeLinkStyleUnknown;

		if (![[NSFileManager defaultManager] fileExistsAtPath:worktree.path]) {
			worktree.movedPath = main ? [self movedPathOfWorktree:worktree identifier:identifier mainPath:main.path commonDirectory:commonDirectory style:&style] : nil;
			worktree.brokenLink = worktree.movedPath != nil;
			worktree.linkStyle = style;
			continue;
		}

		NSString *target = [self linkTargetOfWorktreeAtPath:worktree.path style:&style];
		worktree.linkStyle = style;
		if (!target)
			continue;

		NSString *administrative = [self canonicalPath:[[commonDirectory stringByAppendingPathComponent:@"worktrees"] stringByAppendingPathComponent:identifier]];
		if ([[self canonicalPath:target] isEqualToString:administrative])
			continue;

		if ([[NSFileManager defaultManager] fileExistsAtPath:target]) {
			NSLog(@"The worktree at %@ links to %@, another repository, so it is left alone", worktree.path, target);
			continue;
		}

		worktree.brokenLink = YES;
	}
}

+ (PBGitWorktreeLinkStyle)linkStyleOfWorktrees:(NSArray<PBGitWorktree *> *)worktrees
{
	PBGitWorktreeLinkStyle shared = PBGitWorktreeLinkStyleUnknown;

	for (PBGitWorktree *worktree in worktrees) {
		if (worktree.linkStyle == PBGitWorktreeLinkStyleUnknown)
			continue;

		if (shared == PBGitWorktreeLinkStyleUnknown)
			shared = worktree.linkStyle;
		else if (shared != worktree.linkStyle)
			return PBGitWorktreeLinkStyleMixed;
	}

	return shared;
}

// The snapshot is compared against the last one to decide whether anything
// changed, and the history list polls, so identity comparison here would
// reload the sidebar on every poll.
- (BOOL)isEqual:(id)object
{
	if (self == object)
		return YES;

	if (![object isKindOfClass:[PBGitWorktree class]])
		return NO;

	PBGitWorktree *other = object;

	return [self.path isEqualToString:other.path]
		&& (self.HEAD == other.HEAD || [self.HEAD isEqualToString:other.HEAD])
		&& (self.branchRefName == other.branchRefName || [self.branchRefName isEqualToString:other.branchRefName])
		&& self.isBare == other.isBare
		&& self.isDetached == other.isDetached
		&& self.isCurrent == other.isCurrent
		&& self.isMain == other.isMain
		&& self.isLocked == other.isLocked
		&& (self.lockReason == other.lockReason || [self.lockReason isEqualToString:other.lockReason])
		&& self.isPrunable == other.isPrunable
		&& (self.prunableReason == other.prunableReason || [self.prunableReason isEqualToString:other.prunableReason])
		&& self.linkStyle == other.linkStyle
		&& self.hasBrokenLink == other.hasBrokenLink
		&& (self.movedPath == other.movedPath || [self.movedPath isEqualToString:other.movedPath]);
}

- (NSUInteger)hash
{
	return self.path.hash ^ self.HEAD.hash ^ self.branchRefName.hash;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@%@%@%@%@%@>", NSStringFromClass([self class]), self.path,
									  self.bare ? @" bare" : @"",
									  self.detached ? @" detached" : (self.branchRefName ? [@" " stringByAppendingString:self.branchRefName] : @""),
									  self.locked ? @" locked" : @"",
									  self.prunable ? @" prunable" : @"",
									  self.brokenLink ? @" broken link" : @""];
}

@end

NS_ASSUME_NONNULL_END
