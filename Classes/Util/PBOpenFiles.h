//
//  PBOpenFiles.h
//  GitX
//
//  Created by Tommy Sparber on 02/08/16.
//  Based on code by Etienne
//

#import <Foundation/Foundation.h>

@class PBChangedFile;

@interface PBOpenFiles : NSObject

+ (void)openFiles:(NSArray<PBChangedFile *> *)selectedFiles with:(NSURL *)workingDirectoryURL;
+ (void)showInFinder:(NSArray<PBChangedFile *> *)selectedFiles with:(NSURL *)workingDirectoryURL;

@end
