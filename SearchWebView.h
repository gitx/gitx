//
//  SearchWebView.h
//  GitX
//
//  Created by German Laullon on 19/03/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@interface WebView (SearchWebView)

- (DOMRange *)highlightAllOccurencesOfString:(NSString*)str;
- (NSInteger)highlightAllOccurencesOfString:(NSString*)str inNode:(DOMNode *)node;
- (void)removeAllHighlights;
- (void)updateSearch:(NSSearchField *)sender;

@end
