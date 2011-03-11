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
		
		NSString *fileTxt = @"";
		if(startFile==@"fileview"){
			fileTxt=[file textContents:&theError];
			if(!theError)
				fileTxt=[GLFileView parseHTML:fileTxt];
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
			[script callWebScriptMethod:@"showFile" withArguments:[NSArray arrayWithObjects:fileTxt, filePath, nil]];
		}else{
			[script callWebScriptMethod:@"setMessage" withArguments:[NSArray arrayWithObjects:[theError localizedDescription], nil]];
		}
	}
	
#ifdef DEBUG_BUILD
	NSString *dom=[[[[view mainFrame] DOMDocument] documentElement] outerHTML];
	NSString *tmpFile=@"~/tmp/test.html";
	[dom writeToFile:[tmpFile stringByExpandingTildeInPath] atomically:true encoding:NSUTF8StringEncoding error:nil];
#endif 
}

#pragma mark JavaScript log.js methods

- (void) selectCommit:(NSString*)c
{
	[historyController selectCommit:[PBGitSHA shaWithString:c]];
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

+ (NSString *) parseHTML:(NSString *)txt
{
	txt=[txt stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	txt=[txt stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	txt=[txt stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	txt=[txt stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
	
	return txt;
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
	txt=[self parseHTML:txt];
	
	NSArray *lines = [txt componentsSeparatedByString:@"\n"];
	NSString *line;
	NSMutableString *res=[NSMutableString string];

	int l_line,l_end;
	int r_line,r_end;

	int i=0;
	do {
		line=[lines objectAtIndex:i];
		if([GLFileView isStartDiff:line]){
			NSString *fileName=[self getFileName:line];
			[res appendString:[NSString stringWithFormat:@"<table id='%@' class='diff'><thead><tr><td colspan='3'><div style='float:left;'>",fileName]];
			do{
				[res appendString:[NSString stringWithFormat:@"<p>%@</p>",line]];
				line=[lines objectAtIndex:++i];
			}while([GLFileView isDiffHeader:line]);
			[res appendString:@"</div>"];
			if(![self isBinaryFile:line]){
				[res appendString:[NSString stringWithFormat:@"<div class='filemerge'><a href='' onclick='openFileMerge(\"%@\",\"{SHA}\"); return false;'><img src='GitX://app:/filemerge' width='32' height='32'/><br/>open in<br/>FileMerge</a></div>",fileName]];
			}
			[res appendString:@"</td></tr></thead><tbody>"];

			if([self isBinaryFile:line]){
				NSArray *files=[self getFilesNames:line];
				if(![[files objectAtIndex:0] isAbsolutePath]){
					[res appendString:[NSString stringWithFormat:@"<tr><td colspan='3'>%@</td></tr>",[files objectAtIndex:0]]];
					if([GLFileView isImage:[files objectAtIndex:0]]){
						[res appendString:[NSString stringWithFormat:@"<tr><td colspan='3'><img src='GitX://{SHA}:/prev/%@'/></td></tr>",[files objectAtIndex:0]]];
					}
				}
				if(![[files objectAtIndex:1] isAbsolutePath]){
					[res appendString:[NSString stringWithFormat:@"<tr><td colspan='3'>%@</td></tr>",[files objectAtIndex:1]]];
					if([GLFileView isImage:[files objectAtIndex:1]]){
						[res appendString:[NSString stringWithFormat:@"<tr><td colspan='3'><img src='GitX://{SHA}/%@'/></td></tr>",[files objectAtIndex:1]]];
					}
				}
			}else{
				do{
					NSString *header=[line substringFromIndex:3];
					NSRange hr = NSMakeRange(0, [header rangeOfString:@" @@"].location);
					header=[header substringWithRange:hr];
					
					NSArray *pos=[header componentsSeparatedByString:@" "];
					NSArray *pos_l=[[pos objectAtIndex:0] componentsSeparatedByString:@","];
					NSArray *pos_r=[[pos objectAtIndex:1] componentsSeparatedByString:@","];
					
					l_end=l_line=abs([[pos_l objectAtIndex:0]integerValue]);
					if ([pos_l count]>1) {
						l_end=l_line+[[pos_l objectAtIndex:1]integerValue];				
					}
					
					r_end=r_line=[[pos_r objectAtIndex:0]integerValue];
					if ([pos_r count]>1) {
						r_end=r_line+[[pos_r objectAtIndex:1]integerValue];
					}
					
					[res appendString:[NSString stringWithFormat:@"<tr class='header'><td colspan='3'>%@</td></tr>",line]];
					do{
						line=[lines objectAtIndex:++i];
						NSString *s=[line substringToIndex:1];
						if([s isEqualToString:@" "]){
							[res appendString:[NSString stringWithFormat:@"<tr><td class='l'>%d</td><td class='r'>%d</td>",l_line++,r_line++]];
						}else if([s isEqualToString:@"-"]){
							[res appendString:[NSString stringWithFormat:@"<tr class='l'><td class='l'>%d</td><td class='r'></td>",l_line++]];
						}else if([s isEqualToString:@"+"]){
							[res appendString:[NSString stringWithFormat:@"<tr class='r'><td class='l'></td><td class='r'>%d</td>",r_line++]];
						}
						[res appendString:[NSString stringWithFormat:@"<td class='code'>%@</td></tr>",[line substringFromIndex:1]]];								
					}while((l_line<l_end) || (r_line<r_end));
					if(i<([lines count]-1)){
						line=[lines objectAtIndex:++i];
					}
				}while([GLFileView isStartBlock:line]);
			}
			[res appendString:@"</tbody></table>"];
		}else {
			i++;
		}
	}while(i<[lines count]);
	
	return res;
}

+(NSString *)getFileName:(NSString *)line
{
	NSRange b = [line rangeOfString:@"b/"];
	NSString *file=[line substringFromIndex:b.location+2];
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
	return (([line length]>12) && [[line substringToIndex:12] isEqualToString:@"Binary files"]);
}

+(BOOL)isStartDiff:(NSString *)line
{
	return (([line length]>10) && [[line substringToIndex:10] isEqualToString:@"diff --git"]);
}

+(BOOL)isStartBlock:(NSString *)line
{
	return (([line length]>3) && [[line substringToIndex:3] isEqualToString:@"@@ "]);
}

- (NSString *) parseBlame:(NSString *)txt
{
	txt=[GLFileView parseHTML:txt];
	
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
	//NSLog(@"%@",res);
	
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



@synthesize groups;
@synthesize logFormat;

@end
