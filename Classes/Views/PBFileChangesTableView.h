//
//  PBFileChangesTableView.h
//  GitX
//
//  Created by Pieter de Bie on 09-10-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PBFileChangesTableView : NSTableView {
}

- (IBAction) stageFilesAction:(id)sender;
- (IBAction) unstageFilesAction:(id)sender;
- (IBAction) openFilesAction:(id)sender;
- (IBAction) ignoreFilesAction:(id)sender;
- (IBAction) showInFinderAction:(id)sender;
- (IBAction) discardFilesAction:(id)sender;
- (IBAction) forceDiscardFilesAction:(id)sender;
- (IBAction) trashFilesAction:(id)sender;

@end
