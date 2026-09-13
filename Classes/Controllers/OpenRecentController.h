//
//  OpenRecentController.h
//  GitX
//
//  Created by Hajo Nils Krabbenhöft on 07.10.10.
//  Copyright 2010 spratpix GmbH & Co. KG. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OpenRecentController : NSWindowController <NSTableViewDataSource, NSTableViewDelegate> {
	IBOutlet NSSearchField *searchField;
	NSURL *selectedResult;
	IBOutlet NSTableView *resultViewer;
}

@property (strong) NSMutableArray *currentResults;
@property (strong) NSMutableArray *possibleResults;

- (void)hide;
- (void)show;
- (void)openSelectedResult;
- (void)reportFailureToOpen:(NSError *)error;

- (IBAction)doSearch:(id)sender;
- (IBAction)changeSelection:(id)sender;
- (IBAction)tableDoubleClick:(id)sender;


@end
