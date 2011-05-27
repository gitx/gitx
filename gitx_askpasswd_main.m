/*
 *  gitx_askpasswd_main.m
 *  GitX
 *
 *  Created by Uli Kusterer on 19.02.10.
 *  Copyright 2010 The Void Software. All rights reserved.
 *
 */

#include <ApplicationServices/ApplicationServices.h>
#import <AppKit/AppKit.h>
#include <errno.h>
#include <string.h>
#include <sys/sysctl.h>
#include <Security/Security.h>
#include <CoreServices/CoreServices.h>
#include <Security/SecKeychain.h>
#include <Security/SecKeychainItem.h>
#include <Security/SecAccess.h>
#include <Security/SecTrustedApplication.h>
#include <Security/SecACL.h>
#include <CoreFoundation/CoreFoundation.h>

#define OKBUTTONWIDTH			100.0
#define OKBUTTONHEIGHT			24.0
#define CANCELBUTTONWIDTH		100.0
#define CANCELBUTTONHEIGHT		24.0
#define	PASSHEIGHT				22.0
#define	PASSLABELHEIGHT			16.0
#define WINDOWAUTOSAVENAME		@"GitXAskPasswordWindowFrame"

// In 10.6, some NSObject categories (like NSWindowDelegate) were changed to
// protocols. Thus to avoid warnings we need to add protocol specifiers, but
// only when compiling for 10.6+.
#ifndef MAC_OS_X_VERSION_10_6
#define MAC_OS_X_VERSION_10_6 1060
#endif

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_6
#define PROTOCOL_10_6(...) <__VA_ARGS__>
#else
#define PROTOCOL_10_6(...)
#endif

@interface GAPAppDelegate : NSObject PROTOCOL_10_6(NSApplicationDelegate)
{
}

@end

NSString*			url;
OSStatus			StorePasswordKeychain (const char *url, UInt32 urlLength, void* password,UInt32 passwordLength);


@implementation GAPAppDelegate 

-(void)yesNo:(NSString *)prompt url:(NSString *)url{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"YES"];
    [alert addButtonWithTitle:@"NO"];
    [alert setMessageText:[NSString stringWithFormat:@"%@?",url]];
    [alert setInformativeText:prompt];
    [alert setAlertStyle:NSWarningAlertStyle];
    NSInteger result = [alert runModal];

    Boolean yes=NO;
    if ( result == NSAlertFirstButtonReturn ) {
        yes=YES;
    }
    [alert release];
    printf("%s",yes?"yes":"no");
}


- (void)pasword:(NSString *)prompt url:(NSString *)url{
    
    NSRect box = NSMakeRect(0, 0, 200, 24);
    
    NSSecureTextField * passView = [[NSSecureTextField alloc] initWithFrame: box];
    [passView setSelectable: YES];
    [passView setEditable: YES];
    [passView setBordered: YES];
    [passView setBezeled: YES];
    [passView setBezelStyle: NSTextFieldSquareBezel];
    [passView selectText: self];
    
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"Ok"];
    [alert addButtonWithTitle:@"cancel"];
    [alert setMessageText:[NSString stringWithFormat:@"%@?",url]];
    [alert setInformativeText:prompt];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setAccessoryView:passView]; 
    [alert setShowsSuppressionButton:YES];
    [[alert suppressionButton] setTitle:@"Save on keychain"];
    NSInteger result = [alert runModal];
    if ( result == NSAlertFirstButtonReturn ) {
        NSString *pas=[passView stringValue];
        printf( "%s", [pas UTF8String] );
        if ([[alert suppressionButton] state] == NSOnState) {
            StorePasswordKeychain ([url cStringUsingEncoding:NSASCIIStringEncoding],
                                   [url lengthOfBytesUsingEncoding:NSASCIIStringEncoding],
                                   (void *)[pas cStringUsingEncoding:NSASCIIStringEncoding],
                                   [pas lengthOfBytesUsingEncoding:NSASCIIStringEncoding]);
        }
    }
    
    [alert release];
}

@end

void getproclline(pid_t pid, char *command_name);

void getproclline(pid_t pid, char *command_name)
{
	int		mib[3], argmax, nargs, c = 0;
	size_t		size;
	char		*procargs, *sp, *np, *cp;
	
	mib[0] = CTL_KERN;
	mib[1] = KERN_ARGMAX;
	
	size = sizeof(argmax);
	if (sysctl(mib, 2, &argmax, &size, NULL, 0) == -1) {
		return;
	}
	
	/* Allocate space for the arguments. */
	procargs = (char *)malloc(argmax);
	if (procargs == NULL) {
		return;
	}
	
	mib[0] = CTL_KERN;
	mib[1] = KERN_PROCARGS2;
	mib[2] = pid;
	
	size = (size_t)argmax;
	if (sysctl(mib, 3, procargs, &size, NULL, 0) == -1) {
		return;
	}
	
	memcpy(&nargs, procargs, sizeof(nargs));
	cp = procargs + sizeof(nargs);
	
	/* Skip the saved exec_path. */
	for (; cp < &procargs[size]; cp++) {
		if (*cp == '\0') {
			/* End of exec_path reached. */
			break;
		}
	}
	if (cp == &procargs[size]) {
		return;
	}
	
	/* Skip trailing '\0' characters. */
	for (; cp < &procargs[size]; cp++) {
		if (*cp != '\0') {
			/* Beginning of first argument reached. */
			break;
		}
	}
	if (cp == &procargs[size]) {
		return;
	}
	/* Save where the argv[0] string starts. */
	sp = cp;
	
	for (np = NULL; c < nargs && cp < &procargs[size]; cp++) {
		if (*cp == '\0') {
			c++;
			if (np != NULL) {
				*np = ' ';
			}
			np = cp;
		}
	}	
	sprintf(command_name, "%s",sp);
}

OSStatus StorePasswordKeychain (const char *url, UInt32 urlLength, void* password,UInt32 passwordLength)
{
	OSStatus status;
	status = SecKeychainAddGenericPassword (
											NULL,            // default keychain
											4,               // length of service name
											"GitX",          // service name
											urlLength,       // length of account name
											url,             // account name
											passwordLength,  // length of password
											password,        // pointer to password data
											NULL             // the item reference
											);
    return (status);
}

OSStatus GetPasswordKeychain (const char *url, UInt32 urlLength ,void *passwordData,UInt32 *passwordLength,
							  SecKeychainItemRef *itemRef)
{
	OSStatus status ;
	status = SecKeychainFindGenericPassword (
											 NULL,           // default keychain
											 4,              // length of service name
											 "GitX",         // service name
											 urlLength,      // length of account name
											 url,            // account name
											 passwordLength, // length of password
											 passwordData,   // pointer to password data
											 itemRef         // the item reference
											 );
	return (status);
}


int	main( int argc, const char* argv[] )
{
	// close stderr to stop cocoa log messages from being picked up by GitX
	close(STDERR_FILENO);
    
	ProcessSerialNumber	myPSN = { 0, kCurrentProcess };
	TransformProcessType( &myPSN, kProcessTransformToForegroundApplication );
	
	NSApplication *app = [NSApplication sharedApplication];
	GAPAppDelegate *appDel = [[GAPAppDelegate alloc] init];
	[app setDelegate:appDel];
    
	
    char c_args[4024];
    getproclline(getppid(),c_args);
    NSString *cmd=[NSString stringWithFormat:@"%@",[NSString stringWithUTF8String:c_args]];
    
    NSLog(@"cmd: '%@'",cmd);
    
    NSString *prompt;
    NSString *url;
    BOOL yesno=NO;
    NSArray *args=[cmd componentsSeparatedByString:@" "];
    
    if(argc<1){
        prompt=@"Enter your OpenSSH passphrase:";
        url=@"private key";
    }else{
        prompt=[NSString stringWithFormat:@"%@",[NSString stringWithCString:argv[1] encoding:NSASCIIStringEncoding]];
        if([[prompt lowercaseString] rangeOfString:@"yes/no"].location==NSNotFound){
            url=[args objectAtIndex:[args count]-1];
        }else{
            yesno=YES;
            url=[args objectAtIndex:1];
        }
    }
    
    void *passwordData = nil; 
    SecKeychainItemRef itemRef = nil;
    UInt32 passwordLength = 0;
    
    OSStatus status = GetPasswordKeychain ([url cStringUsingEncoding:NSASCIIStringEncoding],[url lengthOfBytesUsingEncoding:NSASCIIStringEncoding],&passwordData,&passwordLength,&itemRef); 
    if (status == noErr)      {
        SecKeychainItemFreeContent (NULL,passwordData);
        NSString *pas=[[NSString stringWithCString:passwordData encoding:NSASCIIStringEncoding] substringToIndex:passwordLength];
        printf( "%s", [pas UTF8String] );
        return 0;
    }
    
    if(yesno){
        [appDel yesNo:prompt url:url];
    }else{
        [appDel pasword:prompt url:url];
    }
    
	return 0;
}
