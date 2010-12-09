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
				fileTxt=[self parseHTML:fileTxt];
		}else if(startFile==@"blame"){
			fileTxt=[file blame:&theError];
			if(!theError)
				fileTxt=[self parseBlame:fileTxt];
		}else if(startFile==@"log"){
			fileTxt=[file log:logFormat error:&theError];		
		}else if(startFile==@"diff"){
			fileTxt=[file diff:diffType error:&theError];
			if(!theError)
				fileTxt=[self parseDiff:fileTxt];
		}
		
		id script = [view windowScriptObject];
		if(!theError){
			NSString *filePath = [file fullPath];
			[script callWebScriptMethod:@"showFile" withArguments:[NSArray arrayWithObjects:fileTxt, filePath, nil]];
		}else{
			[script callWebScriptMethod:@"setMessage" withArguments:[NSArray arrayWithObjects:[theError localizedDescription], nil]];
		}
	}
	
#if 1
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
	NSLog(@"startFile=%@ identifier=%@ groupNumber=%d",startFile,identifier,groupNumber);
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

- (NSString *) parseHTML:(NSString *)txt
{
	txt=[txt stringByReplacingOccurrencesOfString:@"&" withString:@"&amp;"];
	txt=[txt stringByReplacingOccurrencesOfString:@"<" withString:@"&lt;"];
	txt=[txt stringByReplacingOccurrencesOfString:@">" withString:@"&gt;"];
	
	return txt;
}

- (NSString *) parseDiff:(NSString *)txt
{
	txt=[self parseHTML:txt];
	
	NSArray *lines = [txt componentsSeparatedByString:@"\n"];
	NSString *line;
	NSMutableString *res=[NSMutableString string];
	
	[res appendString:@"<table class='diff'>"];
	int i=0;
	while(i<[lines count]){
		line=[lines objectAtIndex:i];
		if([[line substringToIndex:2] isEqualToString:@"@@"]){

			int l_int,l_count,l_line;
			int r_int,r_count,r_line;
			
			NSString *header=[line substringFromIndex:3];
			NSRange hr = NSMakeRange(0, [header rangeOfString:@" @@"].location);
			header=[header substringWithRange:hr];
			
			NSArray *pos=[header componentsSeparatedByString:@" "];
			NSArray *pos_l=[[pos objectAtIndex:0] componentsSeparatedByString:@","];
			NSArray *pos_r=[[pos objectAtIndex:1] componentsSeparatedByString:@","];
			l_line=l_int=abs([[pos_l objectAtIndex:0]integerValue]);
			l_count=[[pos_l objectAtIndex:1]integerValue];
			r_line=r_int=[[pos_r objectAtIndex:0]integerValue];
			r_count=[[pos_r objectAtIndex:1]integerValue];
			
			[res appendString:[NSString stringWithFormat:@"<tr class='header'><td colspan=3>%@</td></tr>",line]];
			
			do{
				line=[lines objectAtIndex:++i];
				NSString *s=[line substringToIndex:1];
				line=[line substringFromIndex:1];
				
				if([s isEqualToString:@" "]){
					[res appendString:[NSString stringWithFormat:@"<tr><td class='l'>%d</td><td class='r'>%d</td>",l_line++,r_line++]];
				}else if([s isEqualToString:@"-"]){
					[res appendString:[NSString stringWithFormat:@"<tr class='l'><td class='l'>%d</td><td class='r'></td>",l_line++]];
				}else if([s isEqualToString:@"+"]){
					[res appendString:[NSString stringWithFormat:@"<tr class='r'><td class='l'></td><td class='r'>%d</td>",r_line++]];
				}
				[res appendString:[NSString stringWithFormat:@"<td class='code'>%@</td></tr>",line]];							   
			}while(l_line<(l_int+l_count) && r_line<(r_int+r_count));

		}
		i++;
	}
	[res appendString:@"</table>"];
	return res;
}

- (NSString *) parseBlame:(NSString *)txt
{
	txt=[self parseHTML:txt];
	
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
				NSRange trunc={0,30};
				NSString *truncate_a=author;
				if([author length]>30){
					truncate_a=[author substringWithRange:trunc];
				}
				NSString *truncate_s=summary;
				if([summary length]>30){
					truncate_s=[summary substringWithRange:trunc];
				}
				NSString *block=[NSString stringWithFormat:@"<td><p class='author'>%@</p><p class='summary'>%@</p></td>\n<td>\n",truncate_a,truncate_s];
				[headers setObject:block forKey:[header objectAtIndex:0]];
			}
			[res appendString:[headers objectForKey:[header objectAtIndex:0]]];
			
			NSMutableString *code=[NSMutableString string];
			do{
				line=[lines objectAtIndex:i++];
			}while([line characterAtIndex:0]!='\t');
			line=[line substringFromIndex:1];
			line=[line stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
			[code appendString:line];
			[code appendString:@"\n"];
			
			int n;
			for(n=1;n<nLines;n++){
				line=[lines objectAtIndex:i++];
				do{
					line=[lines objectAtIndex:i++];
				}while([line characterAtIndex:0]!='\t');
				line=[line substringFromIndex:1];
				line=[line stringByReplacingOccurrencesOfString:@"\t" withString:@"&nbsp;&nbsp;&nbsp;&nbsp;"];
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
