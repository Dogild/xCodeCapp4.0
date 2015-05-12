//
//  ProcessSourceOperation.m
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import "ProcessSourceOperation.h"
#import "CappuccinoProject.h"
#import "CappuccinoProjectController.h"
#import "CappuccinoUtils.h"
#import "TaskManager.h"

NSString * const XCCConversionDidEndNotification = @"XCCConversionDidStopNotification";
NSString * const XCCConversionDidGenerateErrorNotification = @"XCCConversionDidGenerateErrorNotification";
NSString * const XCCConversionDidStartNotification = @"XCCConversionDidStartNotification";

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

@property CappuccinoProjectController *controller;
@property CappuccinoProject *cappuccinoProject;
@property NSString *sourcePath;
@property NSTask *task;

@end


@implementation ProcessSourceOperation

- (id)initWithCappuccinoProject:(CappuccinoProject *)aCappuccinoProject controller:(CappuccinoProjectController*)aCappuccinoController sourcePath:(NSString *)sourcePath
{
    self = [super init];

    if (self)
    {
        self.controller = aCappuccinoController;
        self.cappuccinoProject = aCappuccinoProject;
        self.sourcePath = sourcePath;
    }

    return self;
}

- (NSDictionary*)defaultUserInfo
{
    return @{
      @"controller":self.controller,
      @"cappuccinoProject":self.cappuccinoProject,
      @"sourcePath":self.sourcePath,
      @"operation":self
      };
}

- (void)cancel
{
    if (self.isCancelled)
        return;
    
    [self.task interrupt];
    [self cancelWithUserInfo:[self defaultUserInfo] notificationName:XCCConversionDidGenerateErrorNotification];
}

- (void)cancelWithUserInfo:(NSDictionary*)userInfo notificationName:(NSString*)notificationName
{
    if (self.isCancelled)
        return;
    
    [super cancel];
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:self userInfo:userInfo];
}

- (void)main
{
    if (self.isCancelled)
        return;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    NSDictionary *info = [self defaultUserInfo];
    
    [center postNotificationName:XCCConversionDidStartNotification object:self userInfo:info];

    DDLogVerbose(@"Conversion started: %@", self.sourcePath);
    
    BOOL isXibFile = [CappuccinoUtils isXibFile:self.sourcePath];
    BOOL isObjjFile = [CappuccinoUtils isObjjFile:self.sourcePath];

    if (isXibFile)
    {
        [self launchNib2CibCommandForPath:self.sourcePath];
    }
    else if (isObjjFile)
    {
        [self launchObjj2ObjcSkeletonCommandForPath:self.sourcePath];
        
        if (!self.controller.isLoadingProject)
        {
            if (!isXibFile)
            {
                [self launchObjjCommandForPath:self.sourcePath];
                [self launchCappLintCommandForPath:self.sourcePath];
            }
        }
    }

    DDLogVerbose(@"Conversion ended: %@", self.sourcePath);

    [center postNotificationName:XCCConversionDidEndNotification object:self userInfo:info];
}

- (NSDictionary*)launchTaskForCommand:(NSString*)aCommand arguments:(NSArray*)arguments
{
    DDLogVerbose(@"Running processing task: %@", aCommand);
    
    self.task = [self.controller.taskManager taskWithCommand:aCommand arguments:arguments];
    NSDictionary *taskResult = [self.controller.taskManager runTask:self.task returnType:kTaskReturnTypeAny];
    
    DDLogInfo(@"Processed %@:", self.sourcePath);
    
    return taskResult;
}

- (void)launchObjj2ObjcSkeletonCommandForPath:(NSString*)aPath
{
    if (![self.cappuccinoProject shouldProcessWithObjj2ObjcSkeleton] || self.isCancelled)
        return;
    
    NSMutableDictionary *info = [[self defaultUserInfo] mutableCopy];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCObjj2ObjcSkeletonDidStartNotification object:self userInfo:info];

    NSString *command = @"objj2objcskeleton";
    NSArray *arguments = @[
                  self.sourcePath,
                  self.cappuccinoProject.supportPath
                  ];
    
    NSDictionary *result = [self launchTaskForCommand:command arguments:arguments];
    
    int status = [result[@"status"] intValue];
    
    if (status != 0)
    {
        NSString *response = result[@"response"];
        NSMutableDictionary *errorInfo = [[self defaultUserInfo] mutableCopy];
        
        @try
        {
            errorInfo[@"errors"] = [response propertyList];
        }
        @catch (NSException *exception)
        {
            errorInfo[@"message"] = response;
        }
        
        [self cancelWithUserInfo:errorInfo notificationName:XCCObjj2ObjcSkeletonDidGenerateErrorNotification];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCObjj2ObjcSkeletonDidEndNotification object:self userInfo:info];
}


- (void)launchNib2CibCommandForPath:(NSString*)aPath
{
    if (![self.cappuccinoProject shouldProcessWithNib2Cib] || self.isCancelled)
        return;
    
    NSMutableDictionary *info = [[self defaultUserInfo] mutableCopy];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCNib2CibDidStartNotification object:self userInfo:info];
    
    NSString *command = @"nib2cib";
    NSArray *arguments = @[
                  @"--no-colors",
                  self.sourcePath
                  ];
    
    NSDictionary *result = [self launchTaskForCommand:command arguments:arguments];
    
    int status = [result[@"status"] intValue];
    
    if (status != 0)
    {
        NSString *response = result[@"response"];
        
        if (response.length == 0)
            response = @"An unspecified error occurred";
        
        NSString *message = [NSString stringWithFormat:@"%@\n%@", self.sourcePath.lastPathComponent, response];
        
        NSMutableDictionary *errorInfo = [[self defaultUserInfo] mutableCopy];
        errorInfo[@"message"] = message;
        
        [self cancelWithUserInfo:errorInfo notificationName:XCCNib2CibDidGenerateErrorNotification];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCNib2CibDidEndNotification object:self userInfo:info];
}

- (void)launchObjjCommandForPath:(NSString*)aPath
{
    if (![self.cappuccinoProject shouldProcessWithObjjWarnings] || self.isCancelled)
        return;
    
    NSMutableDictionary *info = [[self defaultUserInfo] mutableCopy];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCObjjDidStartNotification object:self userInfo:info];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCObjjDidEndNotification object:self userInfo:info];
}

- (void)launchCappLintCommandForPath:(NSString*)aPath
{
    if (![self.cappuccinoProject shouldProcessWithCappLint] || self.isCancelled)
        return;
    
    NSMutableDictionary *info = [[self defaultUserInfo] mutableCopy];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCCappLintDidStartNotification object:self userInfo:info];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCCappLintDidEndNotification object:self userInfo:info];
}
@end
