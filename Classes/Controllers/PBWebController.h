//
//  PBWebController.h
//  GitX
//
//  Created by Pieter de Bie on 08-10-08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface PBWebController : NSObject {
	NSString *startFile;
	BOOL finishedLoading;

	// For async git reading
	NSMapTable *callbacks;

	// For the repository access
	__weak IBOutlet id repository;
}

@property (strong) IBOutlet WKWebView *view;
@property NSString *startFile;
@property (weak) id repository;

- (void)setupJavaScriptBridge;
- (void)evaluateJavaScript:(NSString *)script completionHandler:(void (^)(id result, NSError *error))completionHandler;
- (void)callJavaScriptFunction:(NSString *)functionName withArguments:(NSArray *)arguments completionHandler:(void (^)(id result, NSError *error))completionHandler;
- (void)closeView;
@end
