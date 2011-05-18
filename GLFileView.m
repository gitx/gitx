//
//  GLFileView.m
//  GitX
//
//  Created by German Laullon on 14/09/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "GLFileView.h"
#import "PBGitGradientBarView.h"

#define GROUP_LABEL				@"Label"			// string
#define GROUP_SEPARATOR			@"HasSeparator"		// BOOL as NSNumber
#define GROUP_SELECTION_MODE	@"SelectionMode"	// MGScopeBarGroupSelectionMode (int) as NSNumber
#define GROUP_ITEMS				@"Items"			// array of dictionaries, each containing the following keys:
#define ITEM_IDENTIFIER			@"Identifier"		// string
#define ITEM_NAME				@"Name"				// string


@interface GLFileView ()

- (void)saveSplitViewPosition;
+ (NSString *)parseDiffBlock:(NSString *)txt;
+ (NSString *)parseDiffHeader:(NSString *)txt;
+ (NSString *)parseDiffChunk:(NSString *)txt;
+ (NSString *)parseBinaryDiff:(NSString *)txt;

@end


@implementation GLFileView

- (void) awakeFromNib
{
	NSString *formatFile = [[NSBundle mainBundle] pathForResource:@"format" ofType:@"html" inDirectory:@"html/views/log"];
	if(formatFile!=nil)
		logFormat=[NSString stringWithContentsOfURL:[NSURL fileURLWithPath:formatFile] encoding:NSUTF8StringEncoding error:nil];
	
	
	startFile = @"fileview";
	//repository = historyController.repository;
	[super awakeFromNib];
	[historyController.treeController addObserver:self forKeyPath:@"selection" options:0 context:@"treeController"];
	
	self.groups = [NSMutableArray arrayWithCapacity:0];
	
	NSArray *items = [NSArray arrayWithObjects:
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   startFile, ITEM_IDENTIFIER, 
					   @"Source", ITEM_NAME, 
					   nil], 
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   @"blame", ITEM_IDENTIFIER, 
					   @"Blame", ITEM_NAME, 
					   nil], 
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   @"log", ITEM_IDENTIFIER, 
					   @"History", ITEM_NAME, 
					   nil], 
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   @"diff", ITEM_IDENTIFIER, 
					   @"Diff", ITEM_NAME, 
					   nil], 
					  nil];
	[self.groups addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							[NSNumber numberWithBool:NO], GROUP_SEPARATOR, 
							[NSNumber numberWithInt:MGRadioSelectionMode], GROUP_SELECTION_MODE, // single selection group.
							items, GROUP_ITEMS, 
							nil]];
	
	NSArray *difft = [NSArray arrayWithObjects:
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   @"l", ITEM_IDENTIFIER, 
					   @"Local", ITEM_NAME, 
					   nil], 
					  [NSDictionary dictionaryWithObjectsAndKeys:
					   @"h", ITEM_IDENTIFIER, 
					   @"HEAD", ITEM_NAME, 
					   nil], 
					  nil];
	[self.groups addObject:[NSDictionary dictionaryWithObjectsAndKeys:
							[NSNumber numberWithBool:NO], GROUP_SEPARATOR, 
							[NSNumber numberWithInt:MGRadioSelectionMode], GROUP_SELECTION_MODE, // single selection group.
							difft, GROUP_ITEMS, 
							@"Diff with:",GROUP_LABEL,
							nil]]; 
	
	[typeBar reloadData];
	
	[fileListSplitView setHidden:YES];
	[self performSelector:@selector(restoreSplitViewPositiion) withObject:nil afterDelay:0];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self showFile];
}

- (void) showFile
{
	NSError *theError = nil;
	NSArray *files=[historyController.treeController selectedObjects];
	if ([files count]>0) {
		PBGitTree *file=[files objectAtIndex:0];
		DLog(@"file=%@ == %@ => %d",file,lastFile,[file isEqualTo:lastFile]);
        if(![file isEqualTo:lastFile]){
            lastFile=file;
            
            NSString *fileTxt = @"";
            if(startFile==@"fileview"){
                fileTxt=[file textContents:&theError];
                if(!theError)
                    fileTxt=[GLFileView escapeHTML:fileTxt];
            }else if(startFile==@"blame"){
                fileTxt=[file blame:&theError];
                if(!theError)
                    fileTxt=[self parseBlame:fileTxt];
            }else if(startFile==@"log"){
                fileTxt=[file log:logFormat error:&theError];		
            }else if(startFile==@"diff"){
                fileTxt=[file diff:diffType error:&theError];
                if(!theError)
                    fileTxt=[GLFileView parseDiff:fileTxt];
            }
            
            id script = [view windowScriptObject];
            if(!theError){
                NSString *filePath = [file fullPath];
                fileTxt=[fileTxt stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
                DLog(@"file.sha='%@'",file.sha);
                fileTxt=[fileTxt stringByReplacingOccurrencesOfString:@"{SHA_PREV}" withString:file.sha];
                if(diffType==@"h") {
                    fileTxt=[fileTxt stringByReplacingOccurrencesOfString:@"{SHA}" withString:@"HEAD"];
                }else {
                    fileTxt=[fileTxt stringByReplacingOccurrencesOfString:@"{SHA}" withString:@"--"];
                }
                [script callWebScriptMethod:@"showFile" withArguments:[NSArray arrayWithObjects:fileTxt, filePath, nil]];
            }else{
                [script callWebScriptMethod:@"setMessage" withArguments:[NSArray arrayWithObjects:[theError localizedDescription], nil]];
            }
            [self updateSearch:searchField];
        }
	}
    
	
#ifdef DEBUG_BUILD
    DOMHTMLElement *dom=(DOMHTMLElement *)[[[view mainFrame] DOMDocument] documentElement];
	NSString *domH=[dom outerHTML];
	NSString *tmpFile=@"~/tmp/test.html";
	[domH writeToFile:[tmpFile stringByExpandingTildeInPath] atomically:true encoding:NSUTF8StringEncoding error:nil];
#endif 
}

#pragma mark JavaScript log.js methods

- (void) selectCommit:(NSString*)c
{
	[historyController selectCommit:[PBGitSHA shaWithString:c]];
}

// TODO: need to be refactoring
- (void) openFileMerge:(NSString*)file sha:(NSString *)sha sha2:(NSString *)sha2;
{
	NSArray *args=[NSArray arrayWithObjects:@"difftool",@"--no-prompt",@"--tool=opendiff",sha,sha2,file,nil];
	[historyController.repository handleInWorkDirForArguments:args];
}

#pragma mark MGScopeBarDelegate methods

- (int)numberOfGroupsInScopeBar:(MGScopeBar *)theScopeBar
{
	return [self.groups count];
}


- (NSArray *)scopeBar:(MGScopeBar *)theScopeBar itemIdentifiersForGroup:(int)groupNumber
{
	return [[self.groups objectAtIndex:groupNumber] valueForKeyPath:[NSString stringWithFormat:@"%@.%@", GROUP_ITEMS, ITEM_IDENTIFIER]];
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar labelForGroup:(int)groupNumber
{
	return [[self.groups objectAtIndex:groupNumber] objectForKey:GROUP_LABEL]; // might be nil, which is fine (nil means no label).
}


- (NSString *)scopeBar:(MGScopeBar *)theScopeBar titleOfItem:(NSString *)identifier inGroup:(int)groupNumber
{
	NSArray *items = [[self.groups objectAtIndex:groupNumber] objectForKey:GROUP_ITEMS];
	if (items) {
		for (NSDictionary *item in items) {
			if ([[item objectForKey:ITEM_IDENTIFIER] isEqualToString:identifier]) {
				return [item objectForKey:ITEM_NAME];
				break;
			}
		}
	}
	return nil;
}


- (MGScopeBarGroupSelectionMode)scopeBar:(MGScopeBar *)theScopeBar selectionModeForGroup:(int)groupNumber
{
	return [[[self.groups objectAtIndex:groupNumber] objectForKey:GROUP_SELECTION_MODE] intValue];
}

- (void)scopeBar:(MGScopeBar *)theScopeBar selectedStateChanged:(BOOL)selected forItem:(NSString *)identifier inGroup:(int)groupNumber
{
	if((groupNumber==0) && (startFile!=identifier)){
		NSString *path = [NSString stringWithFormat:@"html/views/%@", identifier];
		NSString *html = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html" inDirectory:path];
		NSURLRequest * request = [NSURLRequest requestWithURL:[NSURL fileURLWithPath:html]];
		[[view mainFrame] loadRequest:request];
		startFile=identifier;
	}else if(groupNumber==1){
		diffType=identifier;
		if(startFile==@"diff"){
			[[view mainFrame] reload];
		}
	}
    lastFile=nil;
}

- (NSView *)accessoryViewForScopeBar:(MGScopeBar *)scopeBar
{
	return accessoryView;
}

- (void) didLoad
{
	[self showFile];
}

- (void)closeView
{
	[historyController.treeController removeObserver:self forKeyPath:@"selection"];
	[self saveSplitViewPosition];
	
	[super closeView];
}

+ (NSString *) escapeHTML:(NSString *)txt
{
    if (txt == nil)
        return txt;
    NSMutableString *newTxt = [NSMutableString stringWithString:txt];
	[newTxt replaceOccurrencesOfString:@"&" withString:@"&amp;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];
	[newTxt replaceOccurrencesOfString:@"<" withString:@"&lt;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];
	[newTxt replaceOccurrencesOfString:@">" withString:@"&gt;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];
    [newTxt replaceOccurrencesOfString:@"\"" withString:@"&quot;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];
    [newTxt replaceOccurrencesOfString:@"'" withString:@"&apos;" options:NSLiteralSearch range:NSMakeRange(0, [newTxt length])];
	
	return newTxt;
}

+ (NSString *)parseDiffTree:(NSString *)txt withStats:(NSMutableDictionary *)stats
{
	NSInteger granTotal=1;
	for(NSArray *stat in [stats allValues]){
		NSInteger add=[[stat objectAtIndex:0] integerValue];
		NSInteger rem=[[stat objectAtIndex:1] integerValue];
		NSInteger tot=add+rem;
		if(tot>granTotal)
			granTotal=tot;
		[stats setObject:[NSArray arrayWithObjects:[NSNumber numberWithInteger:add],[NSNumber numberWithInteger:rem],[NSNumber numberWithInteger:tot],nil] forKey:[stat objectAtIndex:2]];
	}
	
	NSArray *lines = [txt componentsSeparatedByString:@"\n"];
	NSMutableString *res=[NSMutableString string];
	[res appendString:@"<table id='filelist'>"];
	for (NSString *line in lines) {
		if([line length]<98) continue;
		line=[line substringFromIndex:97];
		NSArray *fileStatus=[line componentsSeparatedByString:@"\t"];
		NSString *status=[[fileStatus objectAtIndex:0] substringToIndex:1]; // ignore the score
		NSString *file=[fileStatus objectAtIndex:1];
		NSString *txt=file;
		NSString *fileName=file;
		if([status isEqualToString:@"C"] || [status isEqualToString:@"R"]){
			txt=[NSString stringWithFormat:@"%@ -&gt; %@",file,[fileStatus objectAtIndex:2]];
			fileName=[fileStatus objectAtIndex:2];
		}
		
		NSArray *stat=[stats objectForKey:fileName];
		NSInteger add=[[stat objectAtIndex:0] integerValue];
		NSInteger rem=[[stat objectAtIndex:1] integerValue];
		
		[res appendString:@"<tr><td class='name'>"];
		[res appendString:[NSString stringWithFormat:@"<a class='%@' href='#%@' representedFile='%@'>%@</a>",status,file,fileName,txt]];
		[res appendString:@"</td><td class='bar'>"];
		[res appendString:@"<div>"];
		[res appendString:[NSString stringWithFormat:@"<span class='add' style='width:%d%%'></span>",((add*100)/granTotal)]];
		[res appendString:[NSString stringWithFormat:@"<span class='rem' style='width:%d%%'></span>",((rem*100)/granTotal)]];
		[res appendString:@"</div>"];
		[res appendString:[NSString stringWithFormat:@"</td><td class='add'>+ %d</td><td class='rem'>- %d</td></tr>",add,rem]];
	}
	[res appendString:@"</table>"];
	return res;
}

+ (NSString *)parseDiff:(NSString *)txt
{
	txt=[self escapeHTML:txt];
    
	NSMutableString *res=[NSMutableString string];
    NSScanner *scan=[NSScanner scannerWithString:txt];
    NSString *block;
    
    if(![txt hasPrefix:@"diff --"])
        [scan scanUpToString:@"diff --" intoString:&block];  //move to first diff
    
    while([scan scanString:@"diff --" intoString:NULL]){ // is a diff start?
        [scan scanUpToString:@"\ndiff --" intoString:&block];
        [res appendString:[GLFileView parseDiffBlock:[NSString stringWithFormat:@"diff --%@",block]]];
    }
    
    return res;
}

+ (NSString *)parseDiffBlock:(NSString *)txt
{
	NSMutableString *res=[NSMutableString string];
    NSScanner *scan=[NSScanner scannerWithString:txt];
    NSString *block;
    
    [scan scanUpToString:@"\n@@" intoString:&block];
    [res appendString:@"<table class='diff'><thead>"];
    [res appendString:[GLFileView parseDiffHeader:block]];
    [res appendString:@"</td></tr></thead><tbody>"];
    
    if([block rangeOfString:@"Binary files"].location!=NSNotFound){
        [res appendString:[GLFileView parseBinaryDiff:block]];
    }
    
    while([scan scanString:@"@@" intoString:NULL]){
        [scan scanUpToString:@"\n@@" intoString:&block];
        [res appendString:[GLFileView parseDiffChunk:[NSString stringWithFormat:@"@@%@",block]]];
    }
    
    [res appendString:@"</tbody></table>"];
    
    return res;
}

+ (NSString *)parseBinaryDiff:(NSString *)txt
{
	NSMutableString *res=[NSMutableString string];
    NSScanner *scan=[NSScanner scannerWithString:txt];
    NSString *block;
    
    [scan scanUpToString:@"Binary files" intoString:NULL];
    [scan scanUpToString:@"" intoString:&block];
    
    NSArray *files=[self getFilesNames:block];
    [res appendString:@"<tr class='images'><td>"];
    [res appendString:[NSString stringWithFormat:@"%@<br/>",[files objectAtIndex:0]]];
    if(![[files objectAtIndex:0] isAbsolutePath]){
        if([GLFileView isImage:[files objectAtIndex:0]]){
            [res appendString:[NSString stringWithFormat:@"<img src='GitX://{SHA}:/prev/%@'/>",[files objectAtIndex:0]]];
        }
    }
    [res appendString:@"</td><td>=&gt;</td><td>"];
    [res appendString:[NSString stringWithFormat:@"%@<br/>",[files objectAtIndex:1]]];
    if(![[files objectAtIndex:1] isAbsolutePath]){
        if([GLFileView isImage:[files objectAtIndex:1]]){
            [res appendString:[NSString stringWithFormat:@"<img src='GitX://{SHA}:/%@'/>",[files objectAtIndex:1]]];
        }
    }
    [res appendString:@"</td></tr>"];
    
    return res;
}

+ (NSString *)parseDiffChunk:(NSString *)txt
{
    NSEnumerator *lines = [[txt componentsSeparatedByString:@"\n"] objectEnumerator];
    NSMutableString *res=[NSMutableString string];
    
    NSString *line;
    int l_line[32]; // FIXME: make dynamic
    int r_line;
    
    line=[lines nextObject];
    DLog(@"-=%@=-",line);
	
	int arity = 0; /* How many files are merged here? Count the '@'! */
	while ([line characterAtIndex:arity] == '@')
		arity++;
	
    NSRange hr = NSMakeRange(arity+1, [line rangeOfString:@" @@"].location-arity-1);
    NSString *header=[line substringWithRange:hr];
    
    NSArray *pos=[header componentsSeparatedByString:@" "];
    NSArray *pos_r=[[pos objectAtIndex:arity-1] componentsSeparatedByString:@","];
    
	for(int i=0; i<arity-1; i++){
		NSArray *pos_l=[[pos objectAtIndex:i] componentsSeparatedByString:@","];
		l_line[i]=abs([[pos_l objectAtIndex:0]integerValue]);
	}
    r_line=[[pos_r objectAtIndex:0]integerValue];
    
    [res appendString:[NSString stringWithFormat:@"<tr class='header'><td colspan='%d'>%@</td></tr>",arity+1,line]];
    while((line=[lines nextObject])){
        NSString *prefix=[line substringToIndex:arity-1];
        if([prefix rangeOfString:@"-"].location != NSNotFound){
            [res appendString:@"<tr class='l'>"];
			for(int i=0; i<arity-1; i++){
				if([prefix characterAtIndex:i] == '-'){
					[res appendString:[NSString stringWithFormat:@"<td class='l'>%d</td>",l_line[i]++]];
				}else{
					[res appendString:@"<td class='l'></td>"];
				}
			}
            [res appendString:@"<td class='r'></td>"];
        }else if([prefix rangeOfString:@"+"].location != NSNotFound){
            [res appendString:@"<tr class='r'>"];
			for(int i=0; i<arity-1; i++){
				if([prefix characterAtIndex:i] == ' '){
					[res appendString:[NSString stringWithFormat:@"<td class='l'>%d</td>",l_line[i]++]];
				}else{
					[res appendString:@"<td class='l'></td>"];
				}
			}
            [res appendString:[NSString stringWithFormat:@"<td class='r'>%d</td>",r_line++]];
        }else{
			[res appendString:@"<tr>"];
			for(int i=0; i<arity-1; i++){
				[res appendString:[NSString stringWithFormat:@"<td class='l'>%d</td>",l_line[i]++]];
			}
			[res appendString:[NSString stringWithFormat:@"<td class='r'>%d</td>",r_line++]];
		}
		if(![prefix hasPrefix:@"\\"]){
            [res appendString:[NSString stringWithFormat:@"<td class='code'>%@</td></tr>",[line substringFromIndex:arity-1]]];								
        }
    }
    return res;
}

+ (NSString *)parseDiffHeader:(NSString *)txt
{
    NSEnumerator *lines = [[txt componentsSeparatedByString:@"\n"] objectEnumerator];
    NSMutableString *res=[NSMutableString string];
    
    NSString *line=[lines nextObject];
    NSString *fileName=[self getFileName:line];
    [res appendString:[NSString stringWithFormat:@"<tr id='%@'><td colspan='33'><div style='float:left;'>",fileName]];
    do{
        [res appendString:[NSString stringWithFormat:@"<p>%@</p>",line]];
    }while((line=[lines nextObject]));
    [res appendString:@"</div>"];
    
    if([txt rangeOfString:@"Binary files"].location==NSNotFound){
        [res appendString:[NSString stringWithFormat:@"<div class='filemerge'><a href='' onclick='openFileMerge(\"%@\",\"{SHA_PREV}\",\"{SHA}\"); return false;'><img src='GitX://app:/filemerge' width='32' height='32'/><br/>open in<br/>FileMerge</a></div>",fileName]];
    }
    
    [res appendString:@"</td></tr>"];
    
    return res;
}

+(NSString *)getFileName:(NSString *)line
{
    NSRange b = [line rangeOfString:@"b/"];
	if (b.length == 0)
		b = [line rangeOfString:@"--cc "];
	
    NSString *file=[line substringFromIndex:b.location+b.length];
	
    DLog(@"line=%@",line);
    DLog(@"file=%@",file);
    
	return file;
}

+(NSArray *)getFilesNames:(NSString *)line
{
    NSString *a = nil;
    NSString *b = nil;
    NSScanner *scanner=[NSScanner scannerWithString:line];
    if([scanner scanString:@"Binary files " intoString:NULL]){
        [scanner scanUpToString:@" and" intoString:&a];
        [scanner scanString:@"and" intoString:NULL];
        [scanner scanUpToString:@" differ" intoString:&b];
    }
    if (![a isAbsolutePath]) {
        a=[a substringFromIndex:2];
    }
    if (![b isAbsolutePath]) {
        b=[b substringFromIndex:2];
    }
    
    return [NSArray arrayWithObjects:a,b,nil];
}

+(NSString*)mimeTypeForFileName:(NSString*)name
{
    NSString *mimeType = nil;
    NSInteger i=[name rangeOfString:@"." options:NSBackwardsSearch].location;
    if(i!=NSNotFound){
        NSString *ext=[name substringFromIndex:i+1];
        CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (CFStringRef)ext, NULL);
        if(UTI){
            CFStringRef registeredType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
            if(registeredType){
                mimeType = NSMakeCollectable(registeredType);
            }
            CFRelease(UTI);
        }
    }
    return mimeType;
}

+(BOOL)isDiffHeader:(NSString*)line
{
    unichar c=[line characterAtIndex:0];
    return (c=='i') || (c=='m') || (c=='n') || (c=='d') || (c=='-') || (c=='+'); 
}

+(BOOL)isImage:(NSString*)file
{
    NSString *mimeType=[GLFileView mimeTypeForFileName:file];
    return (mimeType!=nil) && ([mimeType rangeOfString:@"image/" options:NSCaseInsensitiveSearch].location!=NSNotFound);
}

+(BOOL)isBinaryFile:(NSString *)line
{
    return [line hasPrefix:@"Binary files"];
}

+(BOOL)isStartDiff:(NSString *)line
{
    return [line hasPrefix:@"diff --"];
}

+(BOOL)isStartBlock:(NSString *)line
{
    return [line hasPrefix:@"@@"];
}

- (NSString *) parseBlame:(NSString *)txt
{
    txt=[GLFileView escapeHTML:txt];
    
    NSArray *lines = [txt componentsSeparatedByString:@"\n"];
    NSString *line;
    NSMutableDictionary *headers=[NSMutableDictionary dictionary];
    NSMutableString *res=[NSMutableString string];
    
    [res appendString:@"<table class='blocks'>\n"];
    int i=0;
    while(i<[lines count]){
        line=[lines objectAtIndex:i];
        NSArray *header=[line componentsSeparatedByString:@" "];
        if([header count]==4){
            NSString *commitID = (NSString *)[header objectAtIndex:0];
            int nLines=[(NSString *)[header objectAtIndex:3] intValue];
            [res appendFormat:@"<tr class='block l%d'>\n",nLines];
            line=[lines objectAtIndex:++i];
            if([[[line componentsSeparatedByString:@" "] objectAtIndex:0] isEqual:@"author"]){
                NSString *author=[line stringByReplacingOccurrencesOfString:@"author" withString:@""];
                NSString *summary=nil;
                while(summary==nil){
                    line=[lines objectAtIndex:i++];
                    if([[[line componentsSeparatedByString:@" "] objectAtIndex:0] isEqual:@"summary"]){
                        summary=[line stringByReplacingOccurrencesOfString:@"summary" withString:@""];
                    }
                }
                NSRange trunc_c={0,7};
                NSString *truncate_c=commitID;
                if([commitID length]>8){
                    truncate_c=[commitID substringWithRange:trunc_c];
                }
                NSRange trunc={0,22};
                NSString *truncate_a=author;
                if([author length]>22){
                    truncate_a=[author substringWithRange:trunc];
                }
                NSString *truncate_s=summary;
                if([summary length]>30){
                    truncate_s=[summary substringWithRange:trunc];
                }
                NSString *block=[NSString stringWithFormat:@"<td><p class='author'><a href='' onclick='selectCommit(\"%@\"); return false;'>%@</a> %@</p><p class='summary'>%@</p></td>\n<td>\n",commitID,truncate_c,truncate_a,truncate_s];
                [headers setObject:block forKey:[header objectAtIndex:0]];
            }
            [res appendString:[headers objectForKey:[header objectAtIndex:0]]];
            
            NSMutableString *code=[NSMutableString string];
            do{
                line=[lines objectAtIndex:i++];
            }while([line characterAtIndex:0]!='\t');
            line=[line substringFromIndex:1];
            [code appendString:line];
            [code appendString:@"\n"];
            
            int n;
            for(n=1;n<nLines;n++){
                do{
                    line=[lines objectAtIndex:i++];
                }while([line characterAtIndex:0]!='\t');
                line=[line substringFromIndex:1];
                [code appendString:line];
                [code appendString:@"\n"];
            }
            [res appendFormat:@"<pre class='first-line: %@;brush: objc'>%@</pre>",[header objectAtIndex:2],code];
            [res appendString:@"</td>\n"];
        }else{
            break;
        }
        [res appendString:@"</tr>\n"];
    }  
    [res appendString:@"</table>\n"];
    //DLog(@"%@",res);
    
    return (NSString *)res;
}



#pragma mark NSSplitView delegate methods

#define kFileListSplitViewLeftMin 120
#define kFileListSplitViewRightMin 180
#define kHFileListSplitViewPositionDefault @"File List SplitView Position"

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
    return kFileListSplitViewLeftMin;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)dividerIndex
{
    return [splitView frame].size.width - [splitView dividerThickness] - kFileListSplitViewRightMin;
}

// while the user resizes the window keep the left (file list) view constant and just resize the right view
// unless the right view gets too small
- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSRect newFrame = [splitView frame];
    
    float dividerThickness = [splitView dividerThickness];
    
    NSView *leftView = [[splitView subviews] objectAtIndex:0];
    NSRect leftFrame = [leftView frame];
    leftFrame.size.height = newFrame.size.height;
    
    if ((newFrame.size.width - leftFrame.size.width - dividerThickness) < kFileListSplitViewRightMin) {
        leftFrame.size.width = newFrame.size.width - kFileListSplitViewRightMin - dividerThickness;
    }
    
    NSView *rightView = [[splitView subviews] objectAtIndex:1];
    NSRect rightFrame = [rightView frame];
    rightFrame.origin.x = leftFrame.size.width + dividerThickness;
    rightFrame.size.width = newFrame.size.width - rightFrame.origin.x;
    rightFrame.size.height = newFrame.size.height;
    
    [leftView setFrame:leftFrame];
    [rightView setFrame:rightFrame];
}

// NSSplitView does not save and restore the position of the SplitView correctly so do it manually
- (void)saveSplitViewPosition
{
	float position = [[[fileListSplitView subviews] objectAtIndex:0] frame].size.width;
	[[NSUserDefaults standardUserDefaults] setFloat:position forKey:kHFileListSplitViewPositionDefault];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

// make sure this happens after awakeFromNib
- (void)restoreSplitViewPositiion
{
	float position = [[NSUserDefaults standardUserDefaults] floatForKey:kHFileListSplitViewPositionDefault];
	if (position < 1.0)
		position = 200;
	
	[fileListSplitView setPosition:position ofDividerAtIndex:0];
	[fileListSplitView setHidden:NO];
}

#pragma mark IBActions

-(IBAction)updateSearch:(NSSearchField *)sender
{
    [view updateSearch:sender];
}

#pragma mark -


@synthesize groups;
@synthesize logFormat;

@end
