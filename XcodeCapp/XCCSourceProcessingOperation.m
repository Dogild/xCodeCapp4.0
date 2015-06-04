//
//  ProcessSourceOperation.m
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import "XCCSourceProcessingOperation.h"
#import "XCCTaskLauncher.h"

NSString * const XCCConversionDidEndNotification                    = @"XCCConversionDidStopNotification";
NSString * const XCCConversionDidGenerateErrorNotification          = @"XCCConversionDidGenerateErrorNotification";
NSString * const XCCConversionDidStartNotification                  = @"XCCConversionDidStartNotification";
NSString * const XCCObjjDidStartNotification                        = @"XCCObjjDidStartNotification";
NSString * const XCCObjjDidGenerateErrorNotification                = @"XCCObjjDidGenerateErrorNotification";
NSString * const XCCObjjDidEndNotification                          = @"XCCObjjDidEndNotification";
NSString * const XCCCappLintDidStartNotification                    = @"XCCCappLintDidStartNotification";
NSString * const XCCCappLintDidGenerateErrorNotification            = @"XCCCappLintDidGenerateErrorNotification";
NSString * const XCCCappLintDidEndNotification                      = @"XCCCappLintDidEndNotification";
NSString * const XCCObjj2ObjcSkeletonDidStartNotification           = @"XCCObjj2ObjcSkeletonDidStartNotification";
NSString * const XCCObjj2ObjcSkeletonDidGenerateErrorNotification   = @"XCCObjj2ObjcSkeletonDidGenerateErrorNotification";
NSString * const XCCObjj2ObjcSkeletonDidEndNotification             = @"XCCObjj2ObjcSkeletonDidEndNotification";
NSString * const XCCNib2CibDidStartNotification                     = @"XCCNib2CibDidStartNotification";
NSString * const XCCNib2CibDidGenerateErrorNotification             = @"XCCNib2CibDidGenerateErrorNotification";
NSString * const XCCNib2CibDidEndNotification                       = @"XCCNib2CibDidEndNotification";


@implementation XCCSourceProcessingOperation


#pragma mark - Initialization

- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)aCappuccinoProject taskLauncher:(XCCTaskLauncher*)aTaskLauncher sourcePath:(NSString *)sourcePath
{
    if (self = [super initWithCappuccinoProject:aCappuccinoProject taskLauncher:aTaskLauncher])
    {
        self.sourcePath = sourcePath;
    }

    return self;
}


#pragma mark - Utilities

- (NSMutableDictionary *)operationInformations
{
    NSMutableDictionary *info = [super operationInformations];

    info[@"sourcePath"] = self.sourcePath;

    return info;
}

- (void)_updateOperationInformation
{
    NSString *commandName = self->task.launchPath.lastPathComponent;
    NSString *projectPath = [NSString stringWithFormat:@"%@/", self.cappuccinoProject.projectPath];

    if ([commandName isEqualToString:@"objj2objcskeleton"])
        self.operationName = @"Creating Xcode mirror files";

    else if ([commandName isEqualToString:@"nib2cib"])
        self.operationName = @"Converting xib files";

    else if ([commandName isEqualToString:@"objj"])
        self.operationName = @"Checking compilation errors";

    else if ([commandName isEqualToString:@"capp_lint"])
        self.operationName = @"Checking style errors";
    else
        self.operationName = commandName;

    self.operationDescription = [self.sourcePath stringByReplacingOccurrencesOfString:projectPath withString:@""];
}

- (void)_postProcessingErrorNotificationName:(NSString *)notificationName error:(NSString *)errors
{
    if (self.isCancelled)
        return;

    if (errors.length == 0)
        errors = @"An unspecified error occurred";

    NSMutableDictionary *info = [self operationInformations];
    info[@"errors"]           = errors;

    [self dispatchNotificationName:notificationName userInfo:info];
    [self cancel];
}

- (NSDictionary*)_launchTaskWithCommand:(NSString*)aCommand arguments:(NSArray*)arguments
{
    DDLogVerbose(@"Running processing task: %@ on file: %@", aCommand, self.sourcePath);

    self->task = [self->taskLauncher taskWithCommand:aCommand arguments:arguments];

    [self _updateOperationInformation];

    return [self->taskLauncher runTask:self->task returnType:kTaskReturnTypeAny];
}


#pragma Task Launcher

- (void)launchObjj2ObjcSkeletonCommandForPath:(NSString*)aPath
{
    if (self.isCancelled)
        return;
    
    [self dispatchNotificationName:XCCObjj2ObjcSkeletonDidStartNotification];

    NSString        *targetName = [self.cappuccinoProject flattenedXcodeSupportFileNameForPath:aPath];
    NSArray         *arguments  = @[aPath, self.cappuccinoProject.supportPath, @"-n", targetName];
    NSDictionary    *result     = [self _launchTaskWithCommand:@"objj2objcskeleton" arguments:arguments];
    
    if ([result[@"status"] intValue] != 0)
        [self _postProcessingErrorNotificationName:XCCObjj2ObjcSkeletonDidGenerateErrorNotification error:result[@"response"]];

    [self dispatchNotificationName:XCCObjj2ObjcSkeletonDidEndNotification];
}

- (void)launchNib2CibCommandForPath:(NSString*)aPath
{
    if (self.isCancelled)
        return;

    [self dispatchNotificationName:XCCNib2CibDidStartNotification];

    NSArray         *arguments  = @[@"--no-colors", self.sourcePath];
    NSDictionary    *result     = [self _launchTaskWithCommand:@"nib2cib" arguments:arguments];

    if ([result[@"status"] intValue] != 0)
        [self _postProcessingErrorNotificationName:XCCNib2CibDidGenerateErrorNotification error:result[@"response"]];

    [self dispatchNotificationName:XCCNib2CibDidEndNotification];
}

- (void)launchObjjCommandForPath:(NSString*)aPath
{
    if (self.isCancelled)
        return;
    
    [self dispatchNotificationName:XCCObjjDidStartNotification];

    NSArray         *arguments  = @[@"--xml", @"-I", [self.cappuccinoProject objjIncludePath], self.sourcePath];
    NSDictionary    *result     = [self _launchTaskWithCommand:@"objj" arguments:arguments];
    
    if ([result[@"response"] length] != 0)
        [self _postProcessingErrorNotificationName:XCCObjjDidGenerateErrorNotification error:result[@"response"]];

    [self dispatchNotificationName:XCCObjjDidEndNotification];
}

- (void)launchCappLintCommandForPath:(NSString*)aPath
{
    if (self.isCancelled)
        return;
    
    [self dispatchNotificationName:XCCCappLintDidStartNotification];

    NSString        *baseDirectory  = [NSString stringWithFormat:@"--basedir='%@'", self.cappuccinoProject.projectPath];
    NSArray         *arguments      = @[baseDirectory, self.sourcePath];
    NSDictionary    *result         = [self _launchTaskWithCommand:@"capp_lint" arguments:arguments];
    
    if ([result[@"status"] intValue] != 0)
        [self _postProcessingErrorNotificationName:XCCCappLintDidGenerateErrorNotification error:result[@"response"]];

    [self dispatchNotificationName:XCCCappLintDidEndNotification];
}


#pragma mark - NSOperation Protocol

- (void)cancel
{
    if (self->task.isRunning)
        [self->task terminate];

    [super cancel];
}

- (void)main
{
    DDLogVerbose(@"Conversion started: %@", self.sourcePath);

    [self dispatchNotificationName:XCCConversionDidStartNotification];

    @try
    {
        if ([CappuccinoUtils isXibFile:self.sourcePath])
        {
            if (self.cappuccinoProject.processNib2Cib)
                [self launchNib2CibCommandForPath:self.sourcePath];
        }
        else if ([CappuccinoUtils isObjjFile:self.sourcePath])
        {
            if (self.cappuccinoProject.processObjj2ObjcSkeleton)
                [self launchObjj2ObjcSkeletonCommandForPath:self.sourcePath];

            if (self.cappuccinoProject.processObjjWarnings)
                [self launchObjjCommandForPath:self.sourcePath];

            if (self.cappuccinoProject.processCappLint)
                [self launchCappLintCommandForPath:self.sourcePath];
        }

        DDLogVerbose(@"Conversion ended: %@", self.sourcePath);
    }
    @catch (NSException *exception)
    {
        DDLogVerbose(@"Conversion failed: %@", exception);
    }
    @finally
    {
        [self dispatchNotificationName:XCCConversionDidEndNotification];
    }
}

@end
