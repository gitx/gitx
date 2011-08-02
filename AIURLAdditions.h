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


/*!
 * Provides some additional functionality when working with \c NSURL objects.
 */
@interface NSURL (AIURLAdditions)

/**
 * @brief The length of the URL.
 *
 * @return The length (number of characters) of the absolute URL.
 */
@property (readonly, nonatomic) NSUInteger length;

/*!
 * @brief Returns the argument for the specified key in the query string component of
 * the URL.
 *
 * The search is case-sensitive, and the caller is responsible for removing any
 * percent escapes, as well as "+" escapes, too.
 *
 * @param key The key whose value should be located and returned.
 * @return The argument for the specified key, or \c nil if the key could not
 *   be found in the query string.
 */
- (NSString *)queryArgumentForKey:(NSString *)key;
- (NSString *)queryArgumentForKey:(NSString *)key withDelimiter:(NSString *)delimiter;

@end
