//
//  PBGitXProtocol.m
//  GitX
//
//  Created by Pieter de Bie on 01-11-08.
//  Copyright 2008 Pieter de Bie. All rights reserved.
//

#import "PBGitXProtocol.h"


@implementation PBGitXProtocol

- (id)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id <NSURLProtocolClient>)client
{
    // work around for NSURLProtocol bug
    // note that this leaks!
    CFRetain(client);
	
    if ((self = [super initWithRequest:request cachedResponse:cachedResponse client:client]))
    {
    }
	
    return self;
}

+ (BOOL) canInitWithRequest:(NSURLRequest *)request
{
	return [[[request URL] scheme] isEqualToString:@"GitX"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
}

-(void)startLoading
{
    NSURL *url = [[self request] URL];
	PBGitRepository *repo = [[self request] repository];
	
	if(!repo) {
		[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:0 userInfo:nil]];
		return;
    }
	
	if ([[url host] isEqualToString:@"app"]) {
		NSString *app=[[url path] substringFromIndex:1];
		NSString *appPath=[[NSWorkspace sharedWorkspace] fullPathForApplication:app];
		NSLog(@"app=%@ appPath=%@",app,appPath);
		if(appPath){
			NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:appPath];
			NSLog(@"icon=%@",icon);
			[[self client] URLProtocol:self didLoadData:[icon TIFFRepresentation]];
			[[self client] URLProtocolDidFinishLoading:self];
		}else{
			[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:@"gitx" code:404 userInfo:nil]];
		}
	}else {
		
		NSString *path=[[url path] substringFromIndex:1];
		NSString *v=@"";
		if ([[path substringToIndex:5] isEqualToString:@"prev/"]) {
			path=[path substringFromIndex:5];
			v=@"^";
		}
		NSString *specifier = [NSString stringWithFormat:@"%@%@:%@", [url host], v,path];
		handle = [repo handleInWorkDirForArguments:[NSArray arrayWithObjects:@"cat-file", @"blob", specifier, nil]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishFileLoad:) name:NSFileHandleReadToEndOfFileCompletionNotification object:handle];
		[handle readToEndOfFileInBackgroundAndNotify];
		
		NSURLResponse *response = [[NSURLResponse alloc] initWithURL:[[self request] URL]
															MIMEType:nil
											   expectedContentLength:-1
													textEncodingName:nil];
		
		[[self client] URLProtocol:self
				didReceiveResponse:response
				cacheStoragePolicy:NSURLCacheStorageNotAllowed];
	}
}

- (void) didFinishFileLoad:(NSNotification *)notification
{
	NSData *data = [[notification userInfo] valueForKey:NSFileHandleNotificationDataItem];
    [[self client] URLProtocol:self didLoadData:data];
    [[self client] URLProtocolDidFinishLoading:self];
}

- (void) stopLoading
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

@implementation NSURLRequest (PBGitXProtocol)

- (PBGitRepository *) repository
{
	return [NSURLProtocol propertyForKey:@"PBGitRepository" inRequest:self];
}
@end

@implementation NSMutableURLRequest (PBGitXProtocol)
@dynamic repository;

- (void) setRepository:(PBGitRepository *)repository
{
	[NSURLProtocol setProperty:repository forKey:@"PBGitRepository" inRequest:self];
}

@end
