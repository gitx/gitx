//
//  PBWebCommitController.m
//
//  Created by David Catmull on 10-06-11.
//

#import "PBWebCommitController.h"
#import "PBGitCommit.h"
#import "PBGitDefaults.h"
#import "GLFileView.h"
#import <CommonCrypto/CommonDigest.h>

@interface PBWebCommitController (Private)

- (NSArray *)parseHeader:(NSString *)text;
- (NSString *)htmlForHeader:(NSArray *)header withRefs:(NSString *)badges;
- (NSMutableDictionary *)parseStats:(NSString *)txt;
- (NSString *) arbitraryHashForString:(NSString*)concat;

@end


@implementation PBWebCommitController

@synthesize diff;

- (void) awakeFromNib
{
	startFile = @"history";
	[super awakeFromNib];
}

- (void)closeView
{
	[[self script] setValue:nil forKey:@"commit"];
	
	[super closeView];
}

- (void) didLoad
{
	currentSha = nil;
}

- (void) changeContentTo: (PBGitCommit *) content
{
	if (content == nil || !finishedLoading)
		return;
	
	currentSha = [content sha];
	
	// Now we load the extended details. We used to do this in a separate thread,
	// but this caused some funny behaviour because NSTask's and NSThread's don't really
	// like each other. Instead, just do it async.
	
	NSMutableArray *taskArguments = [NSMutableArray arrayWithObjects:@"show", @"--numstat", @"--summary", @"--pretty=raw", currentSha, nil];
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
	
	// Header
	NSArray *headerItems = [self parseHeader:details];
	NSString *header = [self htmlForHeader:details withRefs:[self refsForCurrentCommit]];

	// File Stats
	NSMutableDictionary *stats = [self parseStats:details];

	// File list
	NSString *dt = [repository outputInWorkdirForArguments:[NSArray arrayWithObjects:@"diff-tree", @"--root", @"-r", @"-C90%", @"-M90%", currentSha, nil]];
	NSString *fileList = [GLFileView parseDiffTree:dt withStats:stats];
	
	// Diffs list
	NSString *d = [repository outputInWorkdirForArguments:[NSArray arrayWithObjects:@"diff-tree", @"--root", @"--cc", @"-C90%", @"-M90%", currentSha, nil]];
	NSString *diffs = [GLFileView parseDiff:d];
	
	NSString *html = [NSString stringWithFormat:@"%@%@<div id='diffs'>%@</div>",header,fileList,diffs];
	
	html = [html stringByReplacingOccurrencesOfString:@"{SHA_PREV}" withString:[NSString stringWithFormat:@"%@^",currentSha]];
	html = [html stringByReplacingOccurrencesOfString:@"{SHA}" withString:currentSha];
	
	[[view windowScriptObject] callWebScriptMethod:@"showCommit" withArguments:[NSArray arrayWithObject:html]];
	
#ifdef DEBUG_BUILD
	NSString *dom = [(DOMHTMLElement*)[[[view mainFrame] DOMDocument] documentElement] outerHTML];
	NSString *tmpFile = @"~/tmp/test2.html";
	[dom writeToFile:[tmpFile stringByExpandingTildeInPath] atomically:true encoding:NSUTF8StringEncoding error:nil];
#endif 
}

- (NSString*) refsForCurrentCommit
{
  return @"";
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

// -parseHeader: returns an array of dictionaries with these keys
const NSString *kHeaderKeyName = @"name";
const NSString *kHeaderKeyContent = @"content";

// Keys for the author/committer dictionary
const NSString *kAuthorKeyName = @"name";
const NSString *kAuthorKeyEmail = @"email";
const NSString *kAuthorKeyDate = @"date";

- (NSArray *)parseHeader:(NSString *)text
{
	NSMutableArray *result = [NSMutableArray array];
	NSArray *lines = [text componentsSeparatedByString:@"\n"];
	BOOL parsingSubject = NO;
	
	for (NSString *line in lines) {
		if ([line length] == 0) {
			if (!parsingSubject)
				parsingSubject = TRUE;
			else
				break;
		} else {
			if (parsingSubject) {
				NSString *trimmedLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				[result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						@"subject", kHeaderKeyName, trimmedLine, kHeaderKeyContent, nil]];
			} else {
				NSArray *comps = [line componentsSeparatedByString:@" "];
				if ([comps count] == 2) {
					[result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							[comps objectAtIndex:0], kHeaderKeyName,
							[comps objectAtIndex:1], kHeaderKeyContent, nil]];
				} else if ([comps count] > 2) {
					NSRange r_email_i = [line rangeOfString:@"<"];
					NSRange r_email_e = [line rangeOfString:@">"];
					NSRange r_name_i = [line rangeOfString:@" "];
					
					NSString *name = [line substringWithRange:NSMakeRange(r_name_i.location,(r_email_i.location-r_name_i.location))];
					NSString *email = [line substringWithRange:NSMakeRange(r_email_i.location+1,((r_email_e.location-1)-r_email_i.location))];
					
					NSArray *t=[[line substringFromIndex:r_email_e.location+2] componentsSeparatedByString:@" "];
					NSDate *date=[NSDate dateWithTimeIntervalSince1970:[[t objectAtIndex:0] doubleValue]];
					
					[result addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							[comps objectAtIndex:0], kHeaderKeyName,
							[NSDictionary dictionaryWithObjectsAndKeys:
									name, kAuthorKeyName,
									email, kAuthorKeyEmail,
									date, kAuthorKeyDate,
									nil],
							nil]];
				}
			}
		}
	}
	
	return result;
}

- (NSString *)htmlForHeader:(NSArray *)header withRefs:(NSString *)badges
{
	NSString *last_mail = @"";
	NSMutableString *auths=[NSMutableString string];
	NSMutableString *refs=[NSMutableString string];
	NSMutableString *subject=[NSMutableString string];
	
	for (NSDictionary *item in header) {
		if ([[item objectForKey:kHeaderKeyName] isEqualToString:@"subject"]) {
			[subject appendString:[NSString stringWithFormat:@"%@<br/>",[GLFileView escapeHTML:[item objectForKey:kHeaderKeyContent]]]];
		}else{
			if([[item objectForKey:kHeaderKeyContent] isKindOfClass:[NSString class]]){
				[refs appendString:[NSString stringWithFormat:@"<tr><td>%@</td><td><a href='' onclick='selectCommit(this.innerHTML); return false;'>%@</a></td></tr>",[item objectForKey:kHeaderKeyName],[item objectForKey:kHeaderKeyContent]]];
			}else{  // NSDictionary: author or committer
				NSDictionary *content = [item objectForKey:kHeaderKeyContent];
				NSString *email = [content objectForKey:kAuthorKeyEmail];
				
				if(![email isEqualToString:last_mail]){
					NSString *name = [content objectForKey:kAuthorKeyName];
					NSDate *date = [content objectForKey:kAuthorKeyDate];
					NSDateFormatter* theDateFormatter = [[NSDateFormatter alloc] init];  
					[theDateFormatter setDateStyle:NSDateFormatterMediumStyle];  
					[theDateFormatter setTimeStyle:NSDateFormatterMediumStyle];  
					NSString *dateString=[theDateFormatter stringForObjectValue:date];
									
					[auths appendString:[NSString stringWithFormat:@"<div class='user %@ clearfix'>",rol]];
					if([self isFeatureEnabled:@"gravatar"]){
						NSString *hash=[self arbitraryHashForString:email];
						[auths appendString:[NSString stringWithFormat:@"<img class='avatar' src='http://www.gravatar.com/avatar/%@?d=wavatar&s=30'/>",hash]];
					}
					[auths appendString:[NSString stringWithFormat:@"<p class='name'>%@ <span class='rol'>(%@)</span></p>",name,rol]];
					[auths appendString:[NSString stringWithFormat:@"<p class='time'>%@</p></div>",dateString]];
				}
				last_mail=email;
			}
		}
	}	
	
	return [NSString stringWithFormat:@"<div id='header' class='clearfix'><table class='references'>%@</table><p class='subject'>%@</p>%@<div id='badges'>%@</div></div>",refs,subject,auths,badges];
}

- (NSString *) arbitraryHashForString:(NSString*)concat {
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
}

// TODO: this is duplicated in PBWebDiffController
- (void) openFileMerge:(NSString*)file sha:(NSString *)sha sha2:(NSString *)sha2
{
	NSArray *args=[NSArray arrayWithObjects:@"difftool",@"--no-prompt",@"--tool=opendiff",sha,sha2,@"--",file,nil];
	[repository handleInWorkDirForArguments:args];
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

- (PBGitRef*) refFromString:(NSString*)refString
{
	return nil;
}

- (NSArray*) menuItemsForPath:(NSString*)path
{
	return nil;
}

- (NSArray *)      webView:(WebView *)sender
contextMenuItemsForElement:(NSDictionary *)element
          defaultMenuItems:(NSArray *)defaultMenuItems
{
	DOMNode *node = [element valueForKey:@"WebElementDOMNode"];
	
	while (node) {
		// Every ref has a class name of 'refs' and some other class. We check on that to see if we pressed on a ref.
		if ([[node className] hasPrefix:@"refs "]) {
			NSString *selectedRefString = [[[node childNodes] item:0] textContent];
			PBGitRef *ref = [self refFromString:selectedRefString];
			if (ref != nil)
				return [contextMenuDelegate menuItemsForRef:ref];
			DLog(@"Could not find selected ref!");
			return defaultMenuItems;
		}
		if ([node hasAttributes] && [[node attributes] getNamedItem:@"representedFile"])
			return [self menuItemsForPath:[[[node attributes] getNamedItem:@"representedFile"] value]];
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
	return [repository valueForKeyPath:[@"config." stringByAppendingString:config]];
}

- (void) preferencesChanged
{
	[[self script] callWebScriptMethod:@"enableFeatures" withArguments:nil];
}

@end
