//
//  ProcessSourceOperation.m
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import "ProcessSourceOperation.h"
#import "CappuccinoProject.h"
#import "CappuccinoUtils.h"
#import "TaskManager.h"

NSString * const XCCConversionDidEndNotification = @"XCCConversionDidStopNotification";
NSString * const XCCConversionDidGenerateErrorNotification = @"XCCConversionDidGenerateErrorNotification";
NSString * const XCCConversionDidStartNotification = @"XCCConversionDidStartNotification";
NSString * const XCCConversionDidGenerateCancelNotification = @"XCCConversionDidGenerateCancelNotification";

NSString * const XCCObjjDidStartNotification = @"XCCObjjDidStartNotification";
NSString * const XCCObjjDidGenerateErrorNotification = @"XCCObjjDidGenerateErrorNotification";
NSString * const XCCObjjDidEndNotification = @"XCCObjjDidEndNotification";

NSString * const XCCCappLintDidStartNotification = @"XCCCappLintDidStartNotification";
NSString * const XCCCappLintDidGenerateErrorNotification = @"XCCCappLintDidGenerateErrorNotification";
NSString * const XCCCappLintDidEndNotification = @"XCCCappLintDidEndNotification";

NSString * const XCCObjj2ObjcSkeletonDidStartNotification = @"XCCObjj2ObjcSkeletonDidStartNotification";
NSString * const XCCObjj2ObjcSkeletonDidGenerateErrorNotification = @"XCCObjj2ObjcSkeletonDidGenerateErrorNotification";
NSString * const XCCObjj2ObjcSkeletonDidEndNotification = @"XCCObjj2ObjcSkeletonDidEndNotification";

NSString * const XCCNib2CibDidStartNotification = @"XCCNib2CibDidStartNotification";
NSString * const XCCNib2CibDidGenerateErrorNotification = @"XCCNib2CibDidGenerateErrorNotification";
NSString * const XCCNib2CibDidEndNotification = @"XCCNib2CibDidEndNotification";

@interface ProcessSourceOperation ()

@property TaskManager *taskManager;
@property CappuccinoProject *cappuccinoProject;
@property NSString *sourcePath;

@end


@implementation ProcessSourceOperation

- (id)initWithCappuccinoProject:(CappuccinoProject *)aCappuccinoProject taskManager:(TaskManager*)aTaskManager sourcePath:(NSString *)sourcePath
{
    self = [super init];

    if (self)
    {
        self.taskManager = aTaskManager;
        self.cappuccinoProject = aCappuccinoProject;
        self.sourcePath = sourcePath;
    }

    return self;
}

- (NSString*)operationName
{
    if ([self.task.launchPath.lastPathComponent isEqualToString:@"objj2objcskeleton"])
        return @"Creating Xcode mirror files";
    
    if ([self.task.launchPath.lastPathComponent isEqualToString:@"nib2cib"])
        return @"Converting xib files";

    if ([self.task.launchPath.lastPathComponent isEqualToString:@"objj"])
        return @"Checking compilation errors";

    if ([self.task.launchPath.lastPathComponent isEqualToString:@"capp_lint"])
        return @"Checking style errors";
    
    return self.task.launchPath.lastPathComponent;
}

- (NSString*)operationDescription
{
    NSString *path = [NSString stringWithFormat:@"%@/", self.cappuccinoProject.projectPath];

    return [self.sourcePath stringByReplacingOccurrencesOfString:path withString:@""];
}

- (NSMutableDictionary*)defaultUserInfo
{
    return (NSMutableDictionary*) @{
      @"cappuccinoProject":self.cappuccinoProject,
      @"sourcePath":self.sourcePath,
      @"operation":self
      };
}

- (void)cancel
{
    if (self.isCancelled)
        return;
    
//    [self.task interrupt];
    [self cancelWithUserInfo:[[self defaultUserInfo] mutableCopy] response:@"Operation canceled" notificationName:XCCConversionDidGenerateCancelNotification];
}

- (void)cancelWithUserInfo:(NSMutableDictionary*)userInfo response:(NSString*)aResponse notificationName:(NSString*)notificationName
{
    if (self.isCancelled)
        return;
    
    [super cancel];
    
    if (aResponse.length == 0)
        aResponse = @"An unspecified error occurred";
    
    userInfo[@"errors"] = aResponse;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
    });
}

- (void)main
{
    if (self.isCancelled)
        return;
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSDictionary *info = [self defaultUserInfo];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [center postNotificationName:XCCConversionDidStartNotification object:self userInfo:info];
    });
    DDLogVerbose(@"Conversion started: %@", self.sourcePath);
    
    @try
    {
        BOOL isXibFile = [CappuccinoUtils isXibFile:self.sourcePath];
        BOOL isObjjFile = [CappuccinoUtils isObjjFile:self.sourcePath];
        
        if (isXibFile)
        {
            [self launchNib2CibCommandForPath:self.sourcePath];
        }
        else if (isObjjFile)
        {
            [self launchObjj2ObjcSkeletonCommandForPath:self.sourcePath];
            
            if (!self.cappuccinoProject.isLoading)
            {
                if (!isXibFile)
                {
                    [self launchObjjCommandForPath:self.sourcePath];
                    [self launchCappLintCommandForPath:self.sourcePath];
                }
            }
        }
        
        DDLogVerbose(@"Conversion ended: %@", self.sourcePath);
    }
    @catch (NSException *exception)
    {
        DDLogVerbose(@"Conversion failed: %@", exception);
    }
    @finally
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [center postNotificationName:XCCConversionDidEndNotification object:self userInfo:info];
        });
    }
}

- (NSDictionary*)launchTaskForCommand:(NSString*)aCommand arguments:(NSArray*)arguments
{
    DDLogVerbose(@"Running processing task: %@", aCommand);
    
    [self willChangeValueForKey:@"operationDescription"];
    [self willChangeValueForKey:@"operationName"];
    self.task = [self.taskManager taskWithCommand:aCommand arguments:arguments];
    [self didChangeValueForKey:@"operationDescription"];
    [self didChangeValueForKey:@"operationName"];
    
    NSDictionary *taskResult = [self.taskManager runTask:self.task returnType:kTaskReturnTypeAny];
    
    DDLogInfo(@"Processed %@:", self.sourcePath);
    
    return taskResult;
}

- (void)launchObjj2ObjcSkeletonCommandForPath:(NSString*)aPath
{
    if (![self.cappuccinoProject shouldProcessWithObjj2ObjcSkeleton] || self.isCancelled)
        return;
    
    NSMutableDictionary *info = [[self defaultUserInfo] mutableCopy];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XCCObjj2ObjcSkeletonDidStartNotification object:self userInfo:info];
    });

    NSString *targetName = [self.cappuccinoProject flattenedXcodeSupportFileNameForPath:aPath];
    
    NSString *command = @"objj2objcskeleton";
    NSArray *arguments = @[
                  aPath,
                  self.cappuccinoProject.supportPath,
                  @"-n",
                  targetName
                  ];
    
    NSDictionary *result = [self launchTaskForCommand:command arguments:arguments];
    
    if ([result[@"status"] intValue] != 0)
    {
        NSMutableDictionary *errorInfo = [[self defaultUserInfo] mutableCopy];
        
        [self cancelWithUserInfo:errorInfo response:result[@"response"] notificationName:XCCObjj2ObjcSkeletonDidGenerateErrorNotification];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XCCObjj2ObjcSkeletonDidEndNotification object:self userInfo:info];
    });
}


- (void)launchNib2CibCommandForPath:(NSString*)aPath
{
    if (![self.cappuccinoProject shouldProcessWithNib2Cib] || self.isCancelled)
        return;

    NSMutableDictionary *info = [[self defaultUserInfo] mutableCopy];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XCCNib2CibDidStartNotification object:self userInfo:info];
    });
    
    NSString *command = @"nib2cib";
    NSArray *arguments = @[
                  @"--no-colors",
                  self.sourcePath
                  ];
    
    NSDictionary *result = [self launchTaskForCommand:command arguments:arguments];

    if ([result[@"status"] intValue] != 0)
    {
        NSMutableDictionary *errorInfo = [[self defaultUserInfo] mutableCopy];
        
        [self cancelWithUserInfo:errorInfo response:result[@"response"] notificationName:XCCNib2CibDidGenerateErrorNotification];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XCCNib2CibDidEndNotification object:self userInfo:info];
    });
}

- (void)launchObjjCommandForPath:(NSString*)aPath
{
    if (![self.cappuccinoProject shouldProcessWithObjjWarnings] || self.isCancelled)
        return;
    
    NSMutableDictionary *info = [[self defaultUserInfo] mutableCopy];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XCCObjjDidStartNotification object:self userInfo:info];
    });
    
    NSString *command = @"objj";
    NSArray *arguments = @[
                           @"--xml",
                           @"-I",
                           [self.cappuccinoProject objjIncludePath],
                           self.sourcePath
                           ];
    
    NSDictionary *result = [self launchTaskForCommand:command arguments:arguments];
    
    if ([result[@"response"] length] != 0)
    {
        NSMutableDictionary *errorInfo = [[self defaultUserInfo] mutableCopy];
        
        [self cancelWithUserInfo:errorInfo response:result[@"response"] notificationName:XCCObjjDidGenerateErrorNotification];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XCCObjjDidEndNotification object:self userInfo:info];
    });
}

- (void)launchCappLintCommandForPath:(NSString*)aPath
{
    if (![self.cappuccinoProject shouldProcessWithCappLint] || self.isCancelled)
        return;
    
    NSMutableDictionary *info = [[self defaultUserInfo] mutableCopy];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XCCCappLintDidStartNotification object:self userInfo:info];
    });
    
    NSString *command = @"capp_lint";
    NSString *baseDirectory = [NSString stringWithFormat:@"--basedir='%@'", self.cappuccinoProject.projectPath];
    NSArray *arguments = @[
                           baseDirectory,
                           self.sourcePath
                           ];
    
    NSDictionary *result = [self launchTaskForCommand:command arguments:arguments];
    
    if ([result[@"status"] intValue] != 0)
    {
        NSMutableDictionary *errorInfo = [[self defaultUserInfo] mutableCopy];
        
        [self cancelWithUserInfo:errorInfo response:result[@"response"] notificationName:XCCCappLintDidGenerateErrorNotification];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:XCCCappLintDidEndNotification object:self userInfo:info];
    });
}
@end
