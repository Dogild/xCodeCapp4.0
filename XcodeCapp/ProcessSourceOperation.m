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

@interface ProcessSourceOperation ()

@property CappuccinoProject *cappuccinoProject;
@property NSString *sourcePath;

@end


@implementation ProcessSourceOperation

- (id)initWithCappuccinoProject:(CappuccinoProject *)aCappuccinoProject sourcePath:(NSString *)sourcePath
{
    self = [super init];

    if (self)
    {
        self.cappuccinoProject = aCappuccinoProject;
        self.sourcePath = sourcePath;
    }

    return self;
}

- (void)cancel
{
    if (self.isCancelled)
        return;
    
    [super cancel];
    
    NSDictionary *info =
    @{
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
    
    NSDictionary *info = @{ @"cappuccinoProject":self.cappuccinoProject, @"path":self.sourcePath, @"operation":self};
    [center postNotificationName:XCCConversionDidStartNotification object:self userInfo:info];

    DDLogVerbose(@"Conversion started: %@", self.sourcePath);

    NSString *command = nil;
    NSArray *arguments = nil;
    NSString *response = nil;
    NSString *projectRelativePath = [self.sourcePath substringFromIndex:self.cappuccinoProject.projectPath.length + 1];
    NSString *notificationTitle = nil;
    NSString *notificationMessage = projectRelativePath.lastPathComponent;
    
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
        command = @"objj";
        arguments = @[
                        self.cappuccinoProject.parserPath,
                        self.cappuccinoProject.projectPath,
                        self.sourcePath
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

        NSDictionary *taskResult = [self.cappuccinoProject.taskManager runTaskWithCommand:command
                                                                                arguments:arguments
                                                                               returnType:kTaskReturnTypeAny];

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
                        @"cappuccinoProject":self.cappuccinoProject,
                        @"message":message,
                        @"sourcePath":self.sourcePath,
                        @"status":taskResult[@"status"],
                        @"operation":self
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
        else if (!self.cappuccinoProject.isLoadingProject)
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

        [center postNotificationName:XCCConversionDidEndNotification object:self userInfo:@{ @"cappuccinoProject":self.cappuccinoProject, @"path":self.sourcePath }];
    }
}

- (void)postErrorNotificationForPath:(NSString *)path line:(int)line message:(NSString *)message status:(NSInteger)status
{
    NSDictionary *info = @{@"sourcePath":path,
                           @"line":[NSNumber numberWithInt:line],
                           @"status":[NSNumber numberWithInteger:status],
                           @"operation":self,
                           @"cappuccinoProject":self.cappuccinoProject,
                           @"message":[NSString stringWithFormat:@"Compilation issue: %@, line %d\n%@", [self.sourcePath lastPathComponent], 0, message]
                           };

    if (self.isCancelled)
        return;

    [[NSNotificationCenter defaultCenter] postNotificationName:XCCConversionDidGenerateErrorNotification object:self userInfo:info];
}

@end
