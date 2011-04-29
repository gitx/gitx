//
//  SearchWebView.m
//  GitX
//
//  Created by German Laullon on 19/03/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "SearchWebView.h"

@implementation WebView (SearchWebView)

- (NSInteger)highlightAllOccurencesOfString:(NSString*)str inNode:(DOMNode *)_node
{
    NSInteger count=0;
    DOMDocument *document=[[self mainFrame] DOMDocument];
    
    DOMNodeList *nodes=[_node childNodes];
    DOMNode *node=[nodes item:0];
    while(node!=nil){
        if([node nodeType]==DOM_TEXT_NODE){
            NSString *block;
            if([[node nodeValue] rangeOfString:str options:NSCaseInsensitiveSearch].location!=NSNotFound){
                NSScanner *scanner=[NSScanner scannerWithString:[node nodeValue]];
                [scanner setCharactersToBeSkipped:nil];
                [scanner setCaseSensitive:NO];
                while([scanner scanUpToString:str intoString:&block]){
                    DOMNode *newNode=[document createTextNode:block];
                    [[node parentNode] appendChild:newNode];
                    
                    while([scanner scanString:str intoString:&block]){
                        DOMElement *span=[document createElement:@"span"];
                        [span setAttribute:@"id" value:[NSString stringWithFormat:@"SWVHL_%d",count++]];
                        [span setAttribute:@"class" value:@"SWVHL"];
                        newNode=[document createTextNode:block];
                        [span appendChild:newNode];
                        [[node parentNode] appendChild:span];
                    }
                }
                [[node parentNode] removeChild:node];
            }
        }else if([node nodeType]==DOM_ELEMENT_NODE){
            count+=[self highlightAllOccurencesOfString:str inNode:node];
        }else{
            DLog(@"--->%@",node);
        }
        node=[node nextSibling];
    }
    
    return count;
}

- (DOMRange *)highlightAllOccurencesOfString:(NSString*)str
{
    NSInteger count=0;
    DOMRange *res=nil;
    
    if([[[[self mainFrame] DOMDocument] documentElement] isKindOfClass:[DOMHTMLElement class]]){
        DOMHTMLElement *dom=(DOMHTMLElement *)[[[self mainFrame] DOMDocument] documentElement];
        if(![str isEqualToString:[dom getAttribute:@"searchStr"]]){
            [self removeAllHighlights];
            count=[self highlightAllOccurencesOfString:str inNode:dom];
            if(count>0){
                [dom setAttribute:@"searchStr" value:str];
            }
        }
        if([self searchFor:str direction:YES caseSensitive:NO wrap:YES]){
            res=[self selectedDOMRange];
        }
    }
    
    return res;
}

- (void)updateSearch:(NSSearchField *)sender
{
    NSString *searchString = [sender stringValue];
    DLog(@"searchString:%@",searchString);
    
    DOMRange *selection;
    
    if([searchString length]>0){
        selection=[self highlightAllOccurencesOfString:searchString];
        [[sender window] makeFirstResponder:sender];
        if(selection!=nil)
            [self setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
    }else{
        [self removeAllHighlights];
    }
}

- (void)removeAllHighlights:(DOMNode *)_node
{
    DOMNode *node=[_node firstChild];
    while(node!=nil){
        if ([node nodeType]==DOM_ELEMENT_NODE) {
            if ([[(DOMElement *)node getAttribute:@"class"] isEqualToString:@"SWVHL"]) {
                DOMNode *txt=[node firstChild];
                DOMNode *parent=[node parentNode];
                [node removeChild:txt];
                [parent insertBefore:txt refChild:node];
                [parent removeChild:node];
                [parent normalize];
                [self removeAllHighlights:parent];
            }else{
                [self removeAllHighlights:node];
            }
        }
        node=[node nextSibling];
    }
}

- (void)removeAllHighlights
{
    if([[[[self mainFrame] DOMDocument] documentElement] isKindOfClass:[DOMHTMLElement class]]){
        DOMHTMLElement *dom=(DOMHTMLElement *)[[[self mainFrame] DOMDocument] documentElement];
        [self removeAllHighlights:dom];
    }
}

@end
