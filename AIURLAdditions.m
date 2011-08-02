/* 
 * Adium is the legal property of its developers, whose names are listed in the copyright file included
 * with this source distribution.
 * 
 * This program is free software; you can redistribute it and/or modify it under the terms of the GNU
 * General Public License as published by the Free Software Foundation; either version 2 of the License,
 * or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even
 * the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
 * Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along with this program; if not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#import "AIURLAdditions.h"

@implementation NSURL (AIURLAdditions)

- (NSUInteger)length
{
	return [[self absoluteString] length];
}

- (NSString *)queryArgumentForKey:(NSString *)key withDelimiter:(NSString *)delimiter
{
	for (NSString *obj in [[self query] componentsSeparatedByString:delimiter]) {
		NSArray *keyAndValue = [obj componentsSeparatedByString:@"="];
		
		if (([keyAndValue count] >= 2) && ([[keyAndValue objectAtIndex:0] caseInsensitiveCompare:key] == NSOrderedSame)) {
			return [keyAndValue objectAtIndex:1];
		}
	}
	
	return nil;
}

- (NSString *)queryArgumentForKey:(NSString *)key
{
	NSString		*delimiter;
	
	// The arguments in query strings can be delimited with a semicolon (';') or an ampersand ('&'). Since it's not
	// likely a single URL would use both types of delimeters, we'll attempt to pick one and use it.
	if ([[self query] rangeOfString:@";"].location != NSNotFound) {
		delimiter = @";";
	} else {
		// Assume '&' by default, since that's more common
		delimiter = @"&";
	}
	
	return [self queryArgumentForKey:key withDelimiter:delimiter];
}

@end
