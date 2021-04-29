//
//  PBViewController.h
//  GitX
//
//  Created by Pieter de Bie on 22-09-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PBGitRepository.h"
#import "PBGitWindowController.h"

@interface PBViewController : NSViewController

@property (nonatomic, weak, readonly) PBGitRepository *repository;
@property (weak, readonly) PBGitWindowController *windowController;
@property (copy) NSString *status;
@property (assign) BOOL isBusy;

- (id)initWithRepository:(PBGitRepository *)theRepository superController:(PBGitWindowController *)controller;

/* closeView is called when the repository window will be closed */
- (void)closeView;

/* Updateview is called every time it is loaded into the main view */
- (void)updateView;

- (NSResponder *)firstResponder;
- (IBAction)refresh:(id)sender;

@end
