//
//  PBGitSubmodule.m
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-07.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "PBGitSubmodule.h"

@interface PBGitSubmodule()
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *path;
@property (nonatomic, retain) NSString *checkedOutCommit;
@end


@implementation PBGitSubmodule
@synthesize name;
@synthesize path;
@synthesize checkedOutCommit;
@synthesize submoduleState;
@synthesize submodules;

- (NSMutableArray *) submodules {
	if (!submodules) {
		submodules = [[NSMutableArray alloc] init];
	}
	return submodules;
}

- (id) initWithRawSubmoduleStatusString:(NSString *) submoduleStatusString {
	NSParameterAssert([submoduleStatusString length] > 0);
	
	if ((self = [super init])) {
		unichar status = [submoduleStatusString characterAtIndex:0];
		submoduleState = [PBGitSubmodule submoduleStateFromCharacter:status];
		if (submoduleState == PBGitSubmoduleStateFailed) {
			DLog(@"Submodule status failed:\n %@", submoduleStatusString);
			return nil;
		}
		NSScanner *scanner = [NSScanner scannerWithString:[submoduleStatusString substringFromIndex:1]];
		NSString *sha1 = nil;
		NSString *fullPath = nil;
		NSString *coName = nil;
		BOOL shouldContinue = [scanner scanUpToString:@" " intoString:&sha1];
		if (shouldContinue) {
			shouldContinue = [scanner scanUpToString:@"(" intoString:&fullPath];
		}
		if (shouldContinue) {
			shouldContinue = [scanner scanString:@"(" intoString:NULL];
		}
		if (shouldContinue) {
            [scanner scanUpToString:@")" intoString:&coName];
		}
		self.path = [fullPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		coName = [coName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		self.checkedOutCommit = [coName length] > 0 ? coName : nil;
		self.name = [self.path lastPathComponent];
		
	}
	return self;
}

- (void) dealloc {
	[submodules release];
	[name release];
	[path release];
	[checkedOutCommit release];
	[super dealloc];
}

- (void) addSubmodule:(PBGitSubmodule *) submodule {
	[self.submodules addObject:submodule];
}

#pragma mark -
#pragma mark Presentable

- (NSImage *) icon {
	return [PBGitSubmodule imageForSubmoduleState:self.submoduleState];
}

- (NSString *) displayDescription {
	NSMutableString *result = [[NSMutableString alloc] initWithString:self.name];
	if (self.checkedOutCommit) {
		[result appendFormat:@" (%@)", self.checkedOutCommit];
	}
	return [result autorelease];
}

- (NSString *) popupDescription {
	return [self description];
}


#pragma mark -
#pragma mark Private

+ (NSImage *) imageForSubmoduleState:(PBGitSubmoduleState) state {
	NSString *imageName = nil;
	
	if (state == PBGitSubmoduleStateMatchingIndex) {
		imageName = @"submodule-matching-index.png";
	} else if (state == PBGitSubmoduleStateNotInitialized) {
		imageName = @"submodule-empty.png";
	} else if (state == PBGitSubmoduleStateDoesNotMatchIndex) {
		imageName = @"submodule-notmatching-index.png";
	}
	
	return [NSImage imageNamed:imageName];
}

+ (PBGitSubmoduleState) submoduleStateFromCharacter:(unichar) character {
	PBGitSubmoduleState state = PBGitSubmoduleStateMatchingIndex;
	if (character == '-') {
		state = PBGitSubmoduleStateNotInitialized;
	} else if (character == '+') {
		state = PBGitSubmoduleStateDoesNotMatchIndex;
	} else if (character != ' ') {
		return PBGitSubmoduleStateFailed;
	}

	return state;
}

- (NSString *) description {
	return [NSString stringWithFormat:@"[SUBMODULE] %@(%@) %@", self.name, self.path, self.checkedOutCommit];
}
@end
