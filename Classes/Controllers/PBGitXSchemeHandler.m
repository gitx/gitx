//
//  PBGitXSchemeHandler.m
//  GitX
//
//  Created for WKWebView migration
//

#import "PBGitXSchemeHandler.h"
#import "PBGitRepository.h"
#import "PBGitRepository_PBGitBinarySupport.h"

@implementation PBGitXSchemeHandler

- (void)webView:(WKWebView *)webView startURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask
{
	NSURL *url = urlSchemeTask.request.URL;
	PBGitRepository *repo = self.repository;
	
	if (!repo) {
		NSError *error = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey: @"No repository available"}];
		[urlSchemeTask didFailWithError:error];
		return;
	}
	
	NSString *specifier = [NSString stringWithFormat:@"%@:%@", [url host], [[url path] substringFromIndex:1]];
	PBTask *task = [repo taskWithArguments:@[@"cat-file", @"blob", specifier]];
	
	[task performTaskWithCompletionHandler:^(NSData *readData, NSError *error) {
		if (error) {
			[urlSchemeTask didFailWithError:error];
			return;
		}
		
		NSURLResponse *response = [[NSURLResponse alloc] initWithURL:url
															MIMEType:@"application/octet-stream"
											   expectedContentLength:readData.length
													textEncodingName:nil];
		
		[urlSchemeTask didReceiveResponse:response];
		[urlSchemeTask didReceiveData:readData];
		[urlSchemeTask didFinish];
	}];
}

- (void)webView:(WKWebView *)webView stopURLSchemeTask:(id<WKURLSchemeTask>)urlSchemeTask
{
	// Task cancellation if needed
}

@end
