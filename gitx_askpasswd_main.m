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


@interface GAPAppDelegate : NSObject <NSApplicationDelegate>
{
	NSPanel*			mPasswordPanel;
	NSSecureTextField*	mPasswordField;
	NSButton*			rememberCheck;
}

-(NSPanel*)passwordPanel:(NSString *)prompt remember:(BOOL)remember;

-(IBAction)	doOKButton: (id)sender;
-(IBAction)	doCancelButton: (id)sender;

@end

NSString*			url;
OSStatus			StorePasswordKeychain (const char *url, UInt32 urlLength, void* password,UInt32 passwordLength);


@implementation GAPAppDelegate 

-(NSPanel*)passwordPanel:(NSString *)prompt remember:(BOOL)remember
{
	if( !mPasswordPanel )
	{
		NSRect box = NSMakeRect( 100, 100, 400, 134 );
		mPasswordPanel = [[NSPanel alloc] initWithContentRect: box
													styleMask: NSTitledWindowMask
													  backing: NSBackingStoreBuffered defer: NO];
		[mPasswordPanel setHidesOnDeactivate: NO];
		[mPasswordPanel setLevel: NSFloatingWindowLevel];
		[mPasswordPanel setTitle: @"GitX SSH Remote Login"];
        if (![mPasswordPanel setFrameUsingName: WINDOWAUTOSAVENAME]) {
            [mPasswordPanel center];
            [mPasswordPanel setFrameAutosaveName: WINDOWAUTOSAVENAME];
        }
		
		box.origin = NSZeroPoint;	// Only need local coords from now on.
		
		// OK:
		NSRect okBox = box;
		okBox.origin.x = NSMaxX( box ) -OKBUTTONWIDTH -20;
		okBox.size.width = OKBUTTONWIDTH;
		okBox.origin.y += 20;
		okBox.size.height = OKBUTTONHEIGHT;
		NSButton *okButton = [[NSButton alloc] initWithFrame: okBox];
		[okButton setTarget: self];
		[okButton setAction: @selector(doOKButton:)];
		[okButton setTitle: @"OK"];			// +++ Localize.
		[okButton setKeyEquivalent: @"\r"];
		[okButton setBordered: YES];
		[okButton setBezelStyle: NSRoundedBezelStyle];
		[[mPasswordPanel contentView] addSubview: okButton];
		
		// Cancel:
		NSRect	cancelBox = box;
		cancelBox.origin.x = NSMinX( okBox ) -CANCELBUTTONWIDTH -6;
		cancelBox.size.width = CANCELBUTTONWIDTH;
		cancelBox.origin.y += 20;
		cancelBox.size.height = CANCELBUTTONHEIGHT;
		NSButton *cancleButton = [[NSButton alloc] initWithFrame: cancelBox];
		[cancleButton setTarget: self];
		[cancleButton setAction: @selector(doCancelButton:)];
		[cancleButton setTitle: @"Cancel"];			// +++ Localize.
		[cancleButton setBordered: YES];
		[cancleButton setBezelStyle: NSRoundedBezelStyle];
		[[mPasswordPanel contentView] addSubview: cancleButton];
		
		// Password field:
		NSRect passBox = box;
		passBox.origin.y = NSMaxY(okBox) + 24;
		passBox.size.height = PASSHEIGHT;
		passBox.origin.x += 104;
		passBox.size.width -= 104 + 20;
		mPasswordField = [[NSSecureTextField alloc] initWithFrame: passBox];
		[mPasswordField setSelectable: YES];
		[mPasswordField setEditable: YES];
		[mPasswordField setBordered: YES];
		[mPasswordField setBezeled: YES];
		[mPasswordField setBezelStyle: NSTextFieldSquareBezel];
		[mPasswordField selectText: self];
		[[mPasswordPanel contentView] addSubview: mPasswordField];
		
		// Password label:
		NSRect passLabelBox = box;
		passLabelBox.origin.y = NSMaxY(passBox) + 8;
		passLabelBox.size.height = PASSLABELHEIGHT;
		passLabelBox.origin.x += 100;
		passLabelBox.size.width -= 100 + 20;
		NSTextField *passwordLabel = [[NSTextField alloc] initWithFrame: passLabelBox];
		[passwordLabel setSelectable: YES];
		[passwordLabel setEditable: NO];
		[passwordLabel setBordered: NO];
		[passwordLabel setBezeled: NO];
		[passwordLabel setDrawsBackground: NO];
		[passwordLabel setStringValue: prompt];
		[[mPasswordPanel contentView] addSubview: passwordLabel];
		
		// remember buton:
		if(remember){
			NSRect rememberBox = box;
			rememberBox.origin.x = 100;
			rememberBox.size.width = CANCELBUTTONWIDTH;
			rememberBox.origin.y += 20;
			rememberBox.size.height = CANCELBUTTONHEIGHT;
			rememberCheck = [[NSButton alloc] initWithFrame: rememberBox];
			[rememberCheck setButtonType:NSSwitchButton];
			[rememberCheck setTarget: self];
			[rememberCheck setTitle: @"Remenber"];			// +++ Localize.
			[[mPasswordPanel contentView] addSubview: rememberCheck];
		}
		
		// GitX icon:
		NSRect gitxIconBox = box;
		gitxIconBox.origin.y = NSMaxY(box) - 78;
		gitxIconBox.size.height = 64;
		gitxIconBox.origin.x += 20;
		gitxIconBox.size.width = 64;
		NSImageView *gitxIconView = [[NSImageView alloc] initWithFrame: gitxIconBox];
		[gitxIconView setEditable: NO];
		NSString *gitxIconPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent: @"gitx.icns"];
		NSImage *gitxIcon = [[NSImage alloc] initWithContentsOfFile: gitxIconPath];
		[gitxIconView setImage: gitxIcon];
		[[mPasswordPanel contentView] addSubview: gitxIconView];
	}
	
	return mPasswordPanel;
}


-(IBAction)	doOKButton: (id)sender
{
	NSString *pas=[mPasswordField stringValue];
	printf( "%s", [pas UTF8String] );

	if ((rememberCheck!=nil) && [rememberCheck state]==NSOnState) {
		OSStatus status = StorePasswordKeychain ([url cStringUsingEncoding:NSASCIIStringEncoding],
												 [url lengthOfBytesUsingEncoding:NSASCIIStringEncoding],
												 (void *)[pas cStringUsingEncoding:NSASCIIStringEncoding],
												 [pas lengthOfBytesUsingEncoding:NSASCIIStringEncoding]); //Call
		if (status != noErr) {
			[[NSApplication sharedApplication] stopModalWithCode:-1];
		}
	}
	[[NSApplication sharedApplication] stopModalWithCode:0];
}


// TODO: Need to find out how to get SSH to cancel.
//       When the user cancels the window it is opened again for however
//       many times the remote server allows failed attempts.
-(IBAction)	doCancelButton: (id)sender
{
	[[NSApplication sharedApplication] stopModalWithCode:-1];
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
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	ProcessSerialNumber	myPSN = { 0, kCurrentProcess };
	TransformProcessType( &myPSN, kProcessTransformToForegroundApplication );
	
	NSApplication *app = [NSApplication sharedApplication];
	GAPAppDelegate *appDel = [[GAPAppDelegate alloc] init];
	[app setDelegate: appDel];
	
	char args[4024];
	getproclline(getppid(),args);
	NSString *cmd=[NSString stringWithFormat:@"%@",[NSString stringWithUTF8String:args]];
	
	NSString *prompt=@"???";
	
	url=@"poipoi";
	
	BOOL remember=NO;
	
	if([cmd hasPrefix:@"git-remote-https"]){
		NSArray *args=[cmd componentsSeparatedByString:@" "];
		url=[args objectAtIndex:[args count]-1];
		prompt=[NSString stringWithFormat:@"%@ %@",[NSString stringWithCString:argv[1] encoding:NSASCIIStringEncoding],url];
		remember=YES;
	}else if((sizeof(argv)/sizeof(char*))>1){
		prompt=[NSString stringWithCString:argv[1] encoding:NSASCIIStringEncoding];
	}else{ // only for test
		remember=YES;
		prompt=[NSString stringWithFormat:@"%???? %@",url];
	}
	
	void *passwordData = nil; 
	SecKeychainItemRef itemRef = nil;
	UInt32 passwordLength = 0;
	
	OSStatus status = GetPasswordKeychain ([url cStringUsingEncoding:NSASCIIStringEncoding],[url lengthOfBytesUsingEncoding:NSASCIIStringEncoding],&passwordData,&passwordLength,&itemRef); 
	if (status == noErr)      {
		SecKeychainItemFreeContent (NULL,passwordData);
		NSString *pas=[[NSString stringWithCString:passwordData encoding:NSASCIIStringEncoding] substringToIndex:passwordLength];
		printf( "%s", [pas UTF8String] );
		//NSLog(@"--> '%@'",pas);
		return 0;
	}else if (status != errSecItemNotFound) {
		return -1;
	}

	NSInteger code;
	
	NSWindow *passPanel = [appDel passwordPanel:prompt remember:remember];
	[app activateIgnoringOtherApps: YES];
	[passPanel makeKeyAndOrderFront: nil];
	code = [app runModalForWindow: passPanel];
	
	[defaults synchronize];
	
	return code;
}
