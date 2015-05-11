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

- (void)cancel
{
    if (self.isCancelled)
        return;
    
    [self.task interrupt];
    [super cancel];
    
    NSDictionary *info =
    @{
      @"controller":self.controller,
      @"cappuccinoProject":self.cappuccinoProject,
      @"sourcePath":self.sourcePath,
      @"operation":self
      };
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCConversionDidGenerateErrorNotification object:self userInfo:info];
}

- (void)main
{
    if (self.isCancelled)
        return;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    NSDictionary *info = @{ @"controller":self.controller, @"cappuccinoProject":self.cappuccinoProject, @"path":self.sourcePath};
    [center postNotificationName:XCCConversionDidStartNotification object:self userInfo:info];

    DDLogVerbose(@"Conversion started: %@", self.sourcePath);

    NSString *command = nil;
    NSArray *arguments = nil;
    NSString *response = nil;
    NSString *notificationTitle = nil;
    
    BOOL isXibFile = [CappuccinoUtils isXibFile:self.sourcePath];
    BOOL isObjjFile = [CappuccinoUtils isObjjFile:self.sourcePath];

    if (isXibFile)
    {
        command = @"nib2cib";
        arguments = @[
                        @"--no-colors",
                        self.sourcePath
                    ];

        notificationTitle = @"Xib converted";
    }
    else if (isObjjFile)
    {
        command = @"objj2objcskeleton";
        arguments = @[
                        self.sourcePath,
                        self.cappuccinoProject.supportPath
                     ];

        notificationTitle = @"Objective-J source processed";
    }

    // Run the task and get the response if needed
    NSInteger status = 0;

    if (arguments)
    {
        if (self.isCancelled)
            return;

        DDLogVerbose(@"Running processing task: %@", command);

        self.task = [self.controller.taskManager taskWithCommand:command arguments:arguments];
        NSDictionary *taskResult = [self.controller.taskManager runTask:self.task returnType:kTaskReturnTypeAny];

        status = [taskResult[@"status"] intValue];
        response = taskResult[@"response"];

        DDLogInfo(@"Processed %@: [%ld, %@]", self.sourcePath, status, status ? response : @"");

        if (self.isCancelled)
            return;

        if (status != 0)
        {
            if (isXibFile)
            {
                if (response.length == 0)
                    response = @"An unspecified error occurred";

                notificationTitle = @"Error converting xib";
                NSString *message = [NSString stringWithFormat:@"%@\n%@", self.sourcePath.lastPathComponent, response];

                NSDictionary *info =
                    @{
                        @"controller":self.controller,
                        @"cappuccinoProject":self.cappuccinoProject,
                        @"message":message,
                        @"sourcePath":self.sourcePath,
                        @"status":taskResult[@"status"]
                    };

                if (self.isCancelled)
                    return;

                [center postNotificationName:XCCConversionDidGenerateErrorNotification object:self userInfo:info];
            }
            else
            {
                notificationTitle = [(status == XCCStatusCodeError ? @"Error" : @"Warning") stringByAppendingString:@" parsing Objective-J source"];

                @try
                {
                    NSArray *errors = [response propertyList];

                    for (NSDictionary *error in errors)
                    {
                        [self postErrorNotificationForPath:error[@"path"] line:[error[@"line"] intValue] message:error[@"message"] status:status];
                    }
                }
                @catch (NSException *exception)
                {
                    [self postErrorNotificationForPath:self.sourcePath line:0 message:response status:status];
                }
            }
        }
        else if (!self.controller.isLoadingProject)
        {
//            BOOL showFinalNotification = YES;
//            
//            // At this point, we should only detect warnings
//            if (!isXibFile && [self.cappuccinoProject shouldProcessWithObjjWarnings])
//            {
//                showFinalNotification = [self.xcc checkObjjWarningsForPath:[NSArray arrayWithObject:self.sourcePath]];
//                [self.xcc showObjjWarnings];
//            }
//            
//            if (!isXibFile && [self.cappuccinoProject shouldProcessWithCappLint])
//            {
//                showFinalNotification = [self.xcc checkCappLintForPath:[NSArray arrayWithObject:self.sourcePath]] && showFinalNotification;
//                [self.xcc showCappLintWarnings];
//            }
//
//            if (showFinalNotification)
//                [self notifyUserWithTitle:notificationTitle message:notificationMessage];
        }
    }

    if (!self.isCancelled)
    {
        DDLogVerbose(@"Conversion ended: %@", self.sourcePath);

        [center postNotificationName:XCCConversionDidEndNotification object:self userInfo:@{ @"cappuccinoProject":self.cappuccinoProject, @"path":self.sourcePath, @"controller":self.controller}];
    }
}

- (void)postErrorNotificationForPath:(NSString *)path line:(int)line message:(NSString *)message status:(NSInteger)status
{
    NSDictionary *info = @{
                           @"controller":self.controller,
                           @"sourcePath":path,
                           @"line":[NSNumber numberWithInt:line],
                           @"status":[NSNumber numberWithInteger:status],
                           @"cappuccinoProject":self.cappuccinoProject,
                           @"message":[NSString stringWithFormat:@"Compilation issue: %@, line %d\n%@", [self.sourcePath lastPathComponent], 0, message]
                           };

    if (self.isCancelled)
        return;

    [[NSNotificationCenter defaultCenter] postNotificationName:XCCConversionDidGenerateErrorNotification object:self userInfo:info];
}

@end
