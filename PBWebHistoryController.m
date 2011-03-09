//
//  PBWebGitController.m
//  GitTest
//
//  Created by Pieter de Bie on 14-06-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PBWebHistoryController.h"
#import "PBGitDefaults.h"
#import "PBGitSHA.h"
#import "GLFileView.h"
#import <CommonCrypto/CommonDigest.h>

@implementation PBWebHistoryController

@synthesize diff;

- (void) awakeFromNib
{
	startFile = @"history";
	repository = historyController.repository;
	[super awakeFromNib];
	[historyController addObserver:self forKeyPath:@"webCommit" options:0 context:@"ChangedCommit"];
}

- (void)closeView
{
	[[self script] setValue:nil forKey:@"commit"];
	[historyController removeObserver:self forKeyPath:@"webCommit"];
	
	[super closeView];
}

- (void) didLoad
{
	currentSha = nil;
	[self changeContentTo: historyController.webCommit];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([(NSString *)context isEqualToString: @"ChangedCommit"])
		[self changeContentTo: historyController.webCommit];
	else
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void) changeContentTo: (PBGitCommit *) content
{
	if (content == nil || !finishedLoading)
		return;
	
	currentSha = [content sha];
	
	// Now we load the extended details. We used to do this in a separate thread,
	// but this caused some funny behaviour because NSTask's and NSThread's don't really
	// like each other. Instead, just do it async.
	
	NSMutableArray *taskArguments = [NSMutableArray arrayWithObjects:@"show", @"--numstat", @"--summary", @"--pretty=raw", [currentSha string], nil];
	if (![PBGitDefaults showWhitespaceDifferences])
		[taskArguments insertObject:@"-w" atIndex:1];
	
	NSFileHandle *handle = [repository handleForArguments:taskArguments];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	// Remove notification, in case we have another one running
	[nc removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:nil];
	[nc addObserver:self selector:@selector(commitDetailsLoaded:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle]; 
	[handle readToEndOfFileInBackgroundAndNotify];
}

- (void)commitDetailsLoaded:(NSNotification *)notification
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadToEndOfFileCompletionNotification object:nil];
	
	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
	if (!data)
		return;
	
	NSString *details = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	if (!details)
		details = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	
	if (!details)
		return;
	
	
	NSMutableString *refs=[NSMutableString string];
	NSArray *refsA=[historyController.webCommit refs];
	NSString *currentRef=[[[historyController repository] headRef] simpleRef];
	NSString *style=@"";
	int r=0;
	for(r=0;r<[refsA count];r++){
		PBGitRef *ref=[refsA objectAtIndex:r];
		if([currentRef isEqualToString:[ref ref]]){
			style=[NSString stringWithFormat:@"currentBranch refs %@",[ref type]];
		}else{
			style=[NSString stringWithFormat:@"refs %@",[ref type]];
		}
		[refs appendString:[NSString stringWithFormat:@"<span class='%@'>%@</span>",style,[ref shortName]]];
	}
	
	// Header
	NSString *header=[self parseHeader:details withRefs:refs];

	// File Stats
	NSMutableDictionary *stats=[self parseStats:details];

	// File list
	NSString *dt=[repository outputInWorkdirForArguments:[NSArray arrayWithObjects:@"diff-tree", @"-r", @"-C90%", @"-M90%", [currentSha string], nil]];
	NSString *fileList=[GLFileView parseDiffTree:dt withStats:stats];
	
	// Diffs list
	NSString *d=[repository outputInWorkdirForArguments:[NSArray arrayWithObjects:@"diff-tree", @"--cc", @"-C90%", @"-M90%", [currentSha string], nil]];
	NSString *diffs=[GLFileView parseDiff:d];
	
	NSString *html=[NSString stringWithFormat:@"%@%@<div id='diffs'>%@</div>",header,fileList,diffs];
	
	html=[html stringByReplacingOccurrencesOfString:@"{SHA}" withString:[currentSha string]];
	
	[[view windowScriptObject] callWebScriptMethod:@"showCommit" withArguments:[NSArray arrayWithObject:html]];
	
#ifdef DEBUG_BUILD
	NSString *dom=[[[[view mainFrame] DOMDocument] documentElement] outerHTML];
	NSString *tmpFile=@"~/tmp/test2.html";
	[dom writeToFile:[tmpFile stringByExpandingTildeInPath] atomically:true encoding:NSUTF8StringEncoding error:nil];
#endif 
}

- (NSMutableDictionary *)parseStats:(NSString *)txt
{
	NSArray *lines = [txt componentsSeparatedByString:@"\n"];
	NSMutableDictionary *stats=[NSMutableDictionary dictionary];
	int black=0;
	for(NSString *line in lines){
		if([line length]==0){
			black++;
		}else if(black==2){
			NSArray *file=[line componentsSeparatedByString:@"\t"];
			if([file count]==3){
				[stats setObject:file forKey:[file objectAtIndex:2]];
			}
		}
	}
	return stats;
}

- (NSString *)parseHeader:(NSString *)txt withRefs:(NSString *)badges
{
	NSArray *lines = [txt componentsSeparatedByString:@"\n"];
	NSString *line;
	NSString *last_mail=@"";
	NSMutableString *auths=[NSMutableString string];
	NSMutableString *refs=[NSMutableString string];
	NSMutableString *subject=[NSMutableString string];
	BOOL subj=FALSE;
	
	int i;
	for (i=0; i<[lines count]; i++) {
		line=[lines objectAtIndex:i];
		if([line length]==0){
			if(!subj){
				subj=TRUE;
			}else{
				i=[lines count];
			}
		}else{
			if (subj) {
				[subject appendString:[NSString stringWithFormat:@"%@<br/>",[line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
			}else{
				NSArray *comps=[line componentsSeparatedByString:@" "];
				if([comps count]==2){
					[refs appendString:[NSString stringWithFormat:@"<tr><td>%@</td><td><a href='' onclick='selectCommit(this.innerHTML); return false;'>%@</a></td></tr>",[comps objectAtIndex:0],[comps objectAtIndex:1]]];
				}else if([comps count]>2){
					NSRange r_email_i = [line rangeOfString:@"<"];
					NSRange r_email_e = [line rangeOfString:@">"];
					NSRange r_name_i = [line rangeOfString:@" "];
					
					NSString *rol=[line substringToIndex:r_name_i.location];
					NSString *name=[line substringWithRange:NSMakeRange(r_name_i.location,(r_email_i.location-r_name_i.location))];
					NSString *email=[line substringWithRange:NSMakeRange(r_email_i.location+1,((r_email_e.location-1)-r_email_i.location))];
					
					NSArray *t=[[line substringFromIndex:r_email_e.location+2] componentsSeparatedByString:@" "];
					NSDate *date=[NSDate dateWithTimeIntervalSince1970:[[t objectAtIndex:0] doubleValue]];
					NSDateFormatter* theDateFormatter = [[NSDateFormatter alloc] init];  
					[theDateFormatter setDateStyle:NSDateFormatterMediumStyle];  
					[theDateFormatter setTimeStyle:NSDateFormatterMediumStyle];  
					NSString *dateString=[theDateFormatter stringForObjectValue:date];
										
					if(![email isEqualToString:last_mail]){
						[auths appendString:[NSString stringWithFormat:@"<div class='user %@ clearfix'>",rol]];
						if([self isFeatureEnabled:@"gravatar"]){
							NSString *hash=[self someMethodThatReturnsSomeHashForSomeString:email];
							[auths appendString:[NSString stringWithFormat:@"<img class='avatar' src='http://www.gravatar.com/avatar/%@?d=wavatar&s=30'/>",hash]];
						}
						[auths appendString:[NSString stringWithFormat:@"<p class='name'>%@ <span class='rol'>(%@)</span></p>",name,rol]];
						[auths appendString:[NSString stringWithFormat:@"<p class='time'>%@</p></div>",dateString]];
					}
					last_mail=email;
				}
			}
		}
	}	
	
	return [NSString stringWithFormat:@"<div id='header' class='clearfix'><table class='references'>%@</table><p class='subject'>%@</p>%@<div id='badges'>%@</div></div>",refs,subject,auths,badges];
}

- (NSString *) someMethodThatReturnsSomeHashForSomeString:(NSString*)concat {
	const char *concat_str = [concat UTF8String];
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5(concat_str, strlen(concat_str), result);
	
	NSMutableString *hash = [NSMutableString string];
	
	int i;
	for (i = 0; i < 16; i++)
		[hash appendFormat:@"%02x", result[i]];
	
	return hash;
}

- (void)selectCommit:(NSString *)sha
{
	[historyController selectCommit:[PBGitSHA shaWithString:sha]];
}

- (void) openFileMerge:(NSString*)file sha:(NSString *)sha
{
	NSArray *args=[NSArray arrayWithObjects:@"difftool",@"--no-prompt",@"--tool=opendiff",[NSString stringWithFormat:@"%@^",sha],sha,@"--",file,nil];
	[historyController.repository handleForArguments:args];
}


- (void) sendKey: (NSString*) key
{
	id script = [view windowScriptObject];
	[script callWebScriptMethod:@"handleKeyFromCocoa" withArguments: [NSArray arrayWithObject:key]];
}

- (void) copySource
{
	NSString *source = [(DOMHTMLElement *)[[[view mainFrame] DOMDocument] documentElement] outerHTML];
	NSPasteboard *a =[NSPasteboard generalPasteboard];
	[a declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
	[a setString:source forType: NSStringPboardType];
}

- (NSArray *)	   webView:(WebView *)sender
contextMenuItemsForElement:(NSDictionary *)element
		defaultMenuItems:(NSArray *)defaultMenuItems
{
	DOMNode *node = [element valueForKey:@"WebElementDOMNode"];
	
	while (node) {
		// Every ref has a class name of 'refs' and some other class. We check on that to see if we pressed on a ref.
		if ([[node className] hasPrefix:@"refs "]) {
			NSString *selectedRefString = [[[node childNodes] item:0] textContent];
			for (PBGitRef *ref in historyController.webCommit.refs)
			{
				if ([[ref shortName] isEqualToString:selectedRefString])
					return [contextMenuDelegate menuItemsForRef:ref];
			}
			NSLog(@"Could not find selected ref!");
			return defaultMenuItems;
		}
		if ([node hasAttributes] && [[node attributes] getNamedItem:@"representedFile"])
			return [historyController menuItemsForPaths:[NSArray arrayWithObject:[[[node attributes] getNamedItem:@"representedFile"] value]]];
		else if ([[node class] isEqual:[DOMHTMLImageElement class]]) {
			// Copy Image is the only menu item that makes sense here since we don't need
			// to download the image or open it in a new window (besides with the
			// current implementation these two entries can crash GitX anyway)
			for (NSMenuItem *item in defaultMenuItems)
				if ([item tag] == WebMenuItemTagCopyImageToClipboard)
					return [NSArray arrayWithObject:item];
			return nil;
		}
		
		node = [node parentNode];
	}
	
	return defaultMenuItems;
}


// Open external links in the default browser
-   (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
		  request:(NSURLRequest *)request
	 newFrameName:(NSString *)frameName
 decisionListener:(id < WebPolicyDecisionListener >)listener
{
	[[NSWorkspace sharedWorkspace] openURL:[request URL]];
}

- getConfig:(NSString *)config
{
	return [historyController valueForKeyPath:[@"repository.config." stringByAppendingString:config]];
}

- (void)finalize
{
	[super finalize];
}

- (void) preferencesChanged
{
	[[self script] callWebScriptMethod:@"enableFeatures" withArguments:nil];
}

@end
