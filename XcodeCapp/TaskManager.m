//
//  TaskManager.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "TaskManager.h"

@implementation TaskManager

- (id)init
{
    NSArray *environmentPaths = @[
                                @"/usr/local/narwhal/bin",
                                @"~/narwhal/bin",
                                ];
    
    if (self = [self initWithEnvironementsPaths:environmentPaths])
    {
        
    }
    
    return self;
}

- (id)initWithEnvironementsPaths:(NSArray*)environementsPaths
{
    if (self = [super init])
    {
        DDLogError(@"Init task manager with  environements %@", environementsPaths);
        
        // Add possible executable paths to PATH
        self.environment = [NSProcessInfo processInfo].environment.mutableCopy;
        self.environmentPaths = [environementsPaths mutableCopy];
        
        [self.environmentPaths addObject:@"/usr/bin"];
        [self.environmentPaths addObject:@"/usr/local/bin"];
        [self.environmentPaths addObject:@"~/bin"];
        
        NSMutableArray *paths = [self.environmentPaths mutableCopy];
        
        for (NSInteger i = 0; i < paths.count; ++i)
            paths[i] = [paths[i] stringByExpandingTildeInPath];
        
        self.environment[@"PATH"] = [[paths componentsJoinedByString:@":"] stringByAppendingFormat:@":%@", self.environment[@"PATH"]];
        
        // Make sure we are using jsc as the narwhal engine!
        self.environment[@"NARWHAL_ENGINE"] = @"jsc";
        
        // Make sure to not do something in sudo
        self.environment[@"CAPP_NOSUDO"] = @"1";
        
        self.executables = @[@"python", @"narwhal-jsc", @"objj", @"nib2cib", @"capp", @"capp_lint", @"jake", @"curl", @"unzip", @"rm"];
        
        // This is used to get the env var of $CAPP_BUILD
        NSDictionary *processEnvironment = [[NSProcessInfo processInfo] environment];
        NSArray *arguments = [NSArray arrayWithObjects:@"-l", @"-c", @"echo $CAPP_BUILD", nil];
        
        NSDictionary *taskResult = [self runTaskWithCommand:[processEnvironment objectForKey:@"SHELL"]
                                                  arguments:arguments
                                                 returnType:kTaskReturnTypeStdOut];
        
        // Make sure to remove the \n at the end of the response
        NSString *response = [taskResult[@"response"] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        
        self.environment[@"CAPP_BUILD"] = response;
        
        // Make sure we have found a CAPP_BUILD
        if ([response length] == 0 || [taskResult[@"status"] intValue] == -1)
            _isCappBuildDefined = NO;
        
        self.taskManagerIsValid = [self executablesAreAccessible];
    }
    
    return self;
}

- (BOOL)executablesAreAccessible
{
    for (NSString *executable in self.executables)
    {
        NSDictionary *response = [self runTaskWithCommand:@"/usr/bin/which"
                                                   arguments:@[executable]
                                                  returnType:kTaskReturnTypeStdOut];
        
        NSString *path = [response[@"response"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if (path.length)
            self.executablePaths[executable] = path;
        else
        {
            DDLogError(@"Could not find executable '%@' in PATH: %@", executable, self.environment[@"PATH"]);
            return NO;
        }
    }
    
    DDLogVerbose(@"Executable paths: %@", self.executablePaths);
    
    return YES;
}

/*!
 Run an NSTask with the given arguments
 
 @param aCommand The command to launch
 @param arguments NSArray containing the NSTask arguments
 @param returnType Determines whether to return stdout, stderr, either, or nothing in the response
 @return NSDictionary containing the return status (NSNumber) and the response (NSString)
 */
- (NSDictionary *)runTaskWithCommand:(NSString *)aCommand arguments:(NSArray *)arguments returnType:(XCCTaskReturnType)returnType
{
    return [self runTaskWithCommand:aCommand arguments:arguments returnType:returnType currentDirectoryPath:nil];
}

/*!
 Run an NSTask with the given arguments
 
 @param aCommand The command to launch
 @param arguments NSArray containing the NSTask arguments
 @param returnType Determines whether to return stdout, stderr, either, or nothing in the response
 @param the currentDirectoryPath for the task
 @return NSDictionary containing the return status (NSNumber) and the response (NSString)
 */
- (NSDictionary *)runTaskWithCommand:(NSString *)aCommand arguments:(NSArray *)arguments returnType:(XCCTaskReturnType)returnType currentDirectoryPath:(NSString*)aCurrentDirectoryPath
{
    NSTask *task = [NSTask new];
    
    // TODO : need to change
    NSString *launchPath = self.executablePaths[aCommand];
    
    if (launchPath)
        launchPath = aCommand;
    
    task.launchPath = launchPath;
    task.arguments = arguments;
    task.environment = self.environment;
    task.standardOutput = [NSPipe pipe];
    task.standardError = [NSPipe pipe];
    
    if (aCurrentDirectoryPath)
        task.currentDirectoryPath = aCurrentDirectoryPath;
    
    [task launch];
    
    DDLogVerbose(@"Task launched: %@\n%@", launchPath, arguments);
    
    if (returnType != kTaskReturnTypeNone)
    {
        [task waitUntilExit];
        
        DDLogVerbose(@"Task exited: %@:%d", launchPath, task.terminationStatus);
        
        NSData *data = nil;
        
        if (returnType == kTaskReturnTypeStdOut || returnType == kTaskReturnTypeAny)
            data = [[task.standardOutput fileHandleForReading] availableData];
        
        if (returnType == kTaskReturnTypeStdError || (returnType == kTaskReturnTypeAny && [data length] == 0))
            data = [[task.standardError fileHandleForReading] availableData];
        
        NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSNumber *status = [NSNumber numberWithInt:task.terminationStatus];
        
        return @{ @"status":status, @"response":response };
    }
    else
    {
        return @{ @"status":@0, @"response":@"" };
    }
}

/*!
 Run a jake NSTask with the given arguments
 
 @param arguments NSArray containing the NSTask arguments
 @param the currentDirectoryPath for the task
 @return NSDictionary containing the return status (NSNumber) and the response (NSString)
 */
- (NSDictionary*)runJakeTaskWithArguments:(NSMutableArray*)arguments currentDirectoryPath:(NSString*)aCurrentDirectoryPath
{
    NSString *launchPath = self.executablePaths[@"jake"];
    
    NSTask *task = [NSTask new];
    
    task.launchPath = launchPath;
    task.arguments = arguments;
    task.environment = self.environment;
    task.standardOutput = [NSPipe new];
    task.standardError = [NSPipe new];
    
    if (aCurrentDirectoryPath)
        task.currentDirectoryPath = aCurrentDirectoryPath;
    
    // This is needed to log the jake
    NSFileHandle* fhOut = [task.standardOutput fileHandleForReading];
    [fhOut readInBackgroundAndNotify];
    NSFileHandle* fhErr = [task.standardError fileHandleForReading];
    [fhErr readInBackgroundAndNotify];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jakeReceivedData:) name:NSFileHandleReadCompletionNotification object:fhOut];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jakeReceivedError:) name:NSFileHandleReadCompletionNotification object:fhErr];
    
    [task launch];
    
    DDLogVerbose(@"Task launched: %@\n%@", launchPath, arguments);
    
    [task waitUntilExit];
    
    DDLogVerbose(@"Task exited: %@:%d", launchPath, task.terminationStatus);
    
    NSNumber *status = [NSNumber numberWithInt:task.terminationStatus];
    NSData *data = nil;
    
    if ([status intValue] == 0)
        data = [[task.standardOutput fileHandleForReading] availableData];
    else
        data = [[task.standardError fileHandleForReading] availableData];
    
    NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:fhOut];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleReadCompletionNotification object:fhErr];
    
    return @{@"status" : status, @"response" : response};
}

-(void)jakeReceivedData:(NSNotification*)notification
{
    NSData *data     = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    
    DDLogVerbose(@"Jake receive data\n %@", string);
    
    [[notification object] readInBackgroundAndNotify];
}

-(void)jakeReceivedError:(NSNotification*)notification
{
    NSData *data     = [[notification userInfo] objectForKey:NSFileHandleNotificationDataItem];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    
    DDLogVerbose(@"Jake receive error\%@", string);
}

@end
