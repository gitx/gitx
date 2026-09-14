//
//  NSString_Truncate.m
//  GitX
//
//  Created by Andre Berg on 24.03.10.
//  Copyright 2010 Berg Media. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

#import "NSString_Truncate.h"

@implementation NSString (PBGitXTruncateExtensions)

// Both cutting helpers below take an index into `self` that a naive fixed-width
// truncation would cut at, and nudge it to the nearest composed-character-sequence
// boundary so the cut can't split a surrogate pair (or other multi-UTF-16-unit
// grapheme) in two. Splitting one produces a UTF-16 string half of a surrogate
// pair, which can't be encoded as valid UTF-8 and shows up as a broken glyph
// wherever the truncated string is displayed.

// For a forthcoming -substringToIndex:cutIndex (i.e. the retained prefix ends
// just before cutIndex): if the character at cutIndex belongs to a sequence
// that started earlier, back cutIndex off to the start of that sequence, so
// the whole sequence is dropped rather than half-kept.
- (NSUInteger)pb_indexAtOrBeforeComposedCharacterBoundary:(NSUInteger)cutIndex
{
	if (cutIndex == 0 || cutIndex >= self.length)
		return cutIndex;

	NSRange sequence = [self rangeOfComposedCharacterSequenceAtIndex:cutIndex];
	if (sequence.location < cutIndex)
		return sequence.location;

	return cutIndex;
}

// For a forthcoming -substringFromIndex:cutIndex (i.e. the retained suffix
// starts at cutIndex): if the character at cutIndex belongs to a sequence
// that started earlier, push cutIndex forward past the end of that sequence,
// so the whole sequence is dropped rather than half-kept.
- (NSUInteger)pb_indexAtOrAfterComposedCharacterBoundary:(NSUInteger)cutIndex
{
	if (cutIndex == 0 || cutIndex >= self.length)
		return cutIndex;

	NSRange sequence = [self rangeOfComposedCharacterSequenceAtIndex:cutIndex];
	if (sequence.location < cutIndex)
		return NSMaxRange(sequence);

	return cutIndex;
}

- (NSString *)truncateToLength:(NSUInteger)targetLength mode:(PBNSStringTruncateMode)mode indicator:(NSString *)indicatorString
{
	NSString *res = nil;
	NSString *firstPart;
	NSString *lastPart;

	if (!indicatorString) {
		indicatorString = @"...";
	}

	NSUInteger stringLength = [self length];
	NSUInteger ilength = [indicatorString length];

	if (stringLength <= targetLength) {
		return self;
	} else if (stringLength <= 0 || (!self)) {
		return nil;
	} else {
		// A targetLength shorter than the indicator itself leaves no room for any
		// of the string: without this the subtraction in End mode (targetLength -
		// ilength) underflows NSUInteger into a huge index, and substringToIndex:
		// raises NSRangeException.
		if (targetLength < ilength) {
			targetLength = ilength;
		}
		switch (mode) {
			case PBNSStringTruncateModeCenter: {
				// Center spends half the budget on each end, so the tail it keeps is
				// (targetLength / 2) - ilength characters long: once the indicator
				// alone fills that half, the tail goes negative and pushes lastCut
				// past the end of the string. Keep no tail at all in that case.
				NSUInteger headLength = MIN(targetLength / 2, stringLength);
				NSUInteger tailLength = (targetLength / 2) > ilength ? (targetLength / 2) - ilength : 0;
				NSUInteger firstCut = [self pb_indexAtOrBeforeComposedCharacterBoundary:headLength];
				NSUInteger lastCut = [self pb_indexAtOrAfterComposedCharacterBoundary:(stringLength - tailLength)];
				firstPart = [self substringToIndex:firstCut];
				lastPart = [self substringFromIndex:lastCut];
				res = [NSString stringWithFormat:@"%@%@%@", firstPart, indicatorString, lastPart];
				break;
			}
			case PBNSStringTruncateModeStart: {
				NSUInteger cut = [self pb_indexAtOrAfterComposedCharacterBoundary:((stringLength - targetLength) + ilength)];
				res = [NSString stringWithFormat:@"%@%@", indicatorString, [self substringFromIndex:cut]];
				break;
			}
			case PBNSStringTruncateModeEnd: {
				NSUInteger cut = [self pb_indexAtOrBeforeComposedCharacterBoundary:(targetLength - ilength)];
				res = [NSString stringWithFormat:@"%@%@", [self substringToIndex:cut], indicatorString];
				break;
			}
			default:;
				NSException *myException = [NSException exceptionWithName:NSInvalidArgumentException
																   reason:[NSString stringWithFormat:
																						@"[%@ %@] called with nonsensical value for 'mode' (mode = %d) ***",
																						[self class], NSStringFromSelector(_cmd), mode]
																 userInfo:nil];
				@throw myException;
				return res;
				break;
		};
	}
	return res;
}

@end
