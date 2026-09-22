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
@property (nonatomic, assign, getter=isLocked) BOOL locked;
@property (nonatomic, copy, nullable) NSString *lockReason;
@property (nonatomic, assign, getter=isPrunable) BOOL prunable;
@property (nonatomic, copy, nullable) NSString *prunableReason;

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
		&& self.isLocked == other.isLocked
		&& (self.lockReason == other.lockReason || [self.lockReason isEqualToString:other.lockReason])
		&& self.isPrunable == other.isPrunable
		&& (self.prunableReason == other.prunableReason || [self.prunableReason isEqualToString:other.prunableReason]);
}

- (NSUInteger)hash
{
	return self.path.hash ^ self.HEAD.hash ^ self.branchRefName.hash;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %@%@%@%@%@>", NSStringFromClass([self class]), self.path,
									  self.bare ? @" bare" : @"",
									  self.detached ? @" detached" : (self.branchRefName ? [@" " stringByAppendingString:self.branchRefName] : @""),
									  self.locked ? @" locked" : @"",
									  self.prunable ? @" prunable" : @""];
}

@end

NS_ASSUME_NONNULL_END
