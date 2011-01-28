//
//  PBGitStash.h
//  GitX
//
//  Created by Tomasz Krasnyk on 10-11-06.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PBPresentable.h"

@interface PBGitStash : NSObject<PBPresentable> {
	NSString *stashRawString;
	
	NSString *stashSourceMessage;
	NSString *name;
	NSString *message;
}
@property (nonatomic, retain, readonly) NSString *name;
@property (nonatomic, retain, readonly) NSString *message;
@property (nonatomic, retain, readonly) NSString *stashSourceMessage;
@property (nonatomic, retain, readonly) NSString *stashRawString;

- initWithRawStashLine:(NSString *) stashLineFromStashListOutput;
@end
