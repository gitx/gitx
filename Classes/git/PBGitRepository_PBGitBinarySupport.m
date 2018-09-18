//
//  PBGitRepository_PBGitBinarySupport.m
//  GitX
//
//  Created by Etienne on 22/02/2017.
//
//

#import "PBGitRepository_PBGitBinarySupport.h"

#import "PBEasyPipe.h"
#import "PBGitBinary.h"
#import "PBTask.h"

@implementation PBGitRepository (PBGitBinarySupport)

- (PBTask *)taskWithArguments:(NSArray *)arguments
{
	NSArray *realArgs = @[[@"--git-dir=" stringByAppendingString:self.gitURL.path]];

	// Prepend a --git-dir argument in case we're running against a bare repository
	realArgs = [realArgs arrayByAddingObjectsFromArray:arguments];

	return [PBTask taskWithLaunchPath:[PBGitBinary path] arguments:realArgs inDirectory:self.workingDirectory];
}

- (BOOL)launchTaskWithArguments:(NSArray *)arguments input:(NSString *)inputString error:(NSError **)error
{
	PBTask *task = [self taskWithArguments:arguments];
	task.standardInputData = [inputString dataUsingEncoding:NSUTF8StringEncoding];
	return [task launchTask:error];
}

- (BOOL)launchTaskWithArguments:(NSArray *)arguments error:(NSError **)error
{
	return [self launchTaskWithArguments:arguments input:nil error:error];
}

- (NSString *)outputOfTaskWithArguments:(NSArray *)arguments input:(NSString *)inputString error:(NSError **)error
{
	PBTask *task = [self taskWithArguments:arguments];
	task.standardInputData = [inputString dataUsingEncoding:NSUTF8StringEncoding];
	BOOL success = [task launchTask:error];
	if (!success) return nil;

	NSString *output = [task standardOutputString];
	/* Strip extraneous \n from output */
	if (output.length > 1 && [output characterAtIndex:output.length - 1] == '\n') {
		output = [output stringByReplacingCharactersInRange:NSMakeRange(output.length - 1, 1) withString:@""];
	}
	return output;
}

- (NSString *)outputOfTaskWithArguments:(NSArray *)arguments error:(NSError **)error
{
	return [self outputOfTaskWithArguments:arguments input:nil error:error];
}

@end

@implementation PBGitRepository (PBGitBinarySupportDeprecated)

- (NSFileHandle*) handleForArguments:(NSArray *)args
{
	NSString* gitDirArg = [@"--git-dir=" stringByAppendingString:self.gitURL.path];
	NSMutableArray* arguments =  [NSMutableArray arrayWithObject: gitDirArg];
	[arguments addObjectsFromArray: args];
	return [PBEasyPipe handleForCommand:[PBGitBinary path] withArgs:arguments];
}

- (NSString*) outputForCommand:(NSString *)cmd
{
	NSArray* arguments = [cmd componentsSeparatedByString:@" "];
	return [self outputForArguments: arguments];
}

- (NSString*) outputForCommand:(NSString *)str retValue:(int *)ret;
{
	NSArray* arguments = [str componentsSeparatedByString:@" "];
	return [self outputForArguments: arguments retValue: ret];
}

- (NSString*) outputForArguments:(NSArray*) arguments
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: self.workingDirectory];
}

- (NSString*) outputInWorkdirForArguments:(NSArray*) arguments
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:self.workingDirectory];
}

- (NSString*) outputInWorkdirForArguments:(NSArray *)arguments retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir:self.workingDirectory retValue: ret];
}

- (NSString*) outputForArguments:(NSArray *)arguments retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path] withArgs:arguments inDir: self.workingDirectory retValue: ret];
}

- (NSString*) outputForArguments:(NSArray *)arguments inputString:(NSString *)input retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path]
							   withArgs:arguments
								  inDir:self.workingDirectory
							inputString:input
							   retValue: ret];
}

- (NSString *)outputForArguments:(NSArray *)arguments inputString:(NSString *)input byExtendingEnvironment:(NSDictionary *)dict retValue:(int *)ret
{
	return [PBEasyPipe outputForCommand:[PBGitBinary path]
							   withArgs:arguments
								  inDir:self.workingDirectory
				 byExtendingEnvironment:dict
							inputString:input
							   retValue: ret];
}
@end
