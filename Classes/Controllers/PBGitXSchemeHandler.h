//
//  PBGitXSchemeHandler.h
//  GitX
//
//  Created for WKWebView migration
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class PBGitRepository;

@interface PBGitXSchemeHandler : NSObject <WKURLSchemeHandler>

@property (nonatomic, weak) PBGitRepository *repository;

@end
