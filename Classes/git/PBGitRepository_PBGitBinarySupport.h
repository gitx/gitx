//
//  PBGitRepository_PBGitBinarySupport.h
//  GitX
//
//  Created by Etienne on 22/02/2017.
//
//

#import <Foundation/Foundation.h>
#import "PBGitRepository.h"
#import "PBTask.h" // Imported so our includers don't have to add it

NS_ASSUME_NONNULL_BEGIN

@interface PBGitRepository (PBGitBinarySupport)
- (PBTask *)taskWithArguments:(nullable NSArray *)arguments;
- (BOOL)launchTaskWithArguments:(nullable NSArray *)arguments input:(nullable NSString *)inputString error:(NSError **)error;
- (BOOL)launchTaskWithArguments:(nullable NSArray *)arguments error:(NSError **)error;
- (nullable NSString *)outputOfTaskWithArguments:(nullable NSArray *)arguments input:(nullable NSString *)inputString error:(NSError **)error;
- (nullable NSString *)outputOfTaskWithArguments:(nullable NSArray *)arguments error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
