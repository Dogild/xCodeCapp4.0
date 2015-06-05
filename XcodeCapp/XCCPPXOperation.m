//
//  XCCPbxCreationOperation.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 6/2/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCPPXOperation.h"
#import "XCCCappuccinoProject.h"
#import "XCCTaskLauncher.h"

NSString * const XCCPBXOperationDidStartNotification = @"XCCPbxCreationDidStartNotification";
NSString * const XCCPbxCreationGenerateErrorNotification = @"XCCPbxCreationDidGenerateErrorNotification";
NSString * const XCCPBXOperationDidEndNotification = @"XCCPbxCreationDidEndNotification";


@implementation XCCPPXOperation

#pragma mark - Initialization

- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)aCappuccinoProject taskLauncher:(XCCTaskLauncher*)aTaskLauncher
{
    if (self = [super initWithCappuccinoProject:aCappuccinoProject taskLauncher:aTaskLauncher])
    {
        self.operationDescription       = self.cappuccinoProject.projectPath;
        self.operationName              = @"Updating the Xcode project";

        self->PBXOperations             = [NSMutableDictionary new];
        self->PBXOperations[@"add"]     = [NSMutableArray array];
        self->PBXOperations[@"remove"]  = [NSMutableArray array];

        __block XCCPPXOperation *weakOperation = self;

        self.completionBlock = ^{
            [weakOperation dispatchNotificationName:XCCPBXOperationDidEndNotification];
        };
    }
    
    return self;
}


#pragma mark - PBX Operations

- (void)registerPathToAddInPBX:(NSString *)path
{
    if (![CappuccinoUtils isObjjFile:path])
        return;

    [self->PBXOperations[@"add"] addObject:path];
}

- (void)registerPathToRemoveFromPBX:(NSString *)path
{
    [self->PBXOperations[@"remove"] addObject:path];
}



#pragma mark - NSOperation API

- (void)cancel
{
    if (self->task.isRunning)
        [self->task terminate];

    [super cancel];
}


- (void)main
{
    [self dispatchNotificationName:XCCPBXOperationDidStartNotification];

    DDLogVerbose(@"Pbx creation started: %@", self.cappuccinoProject.projectPath);
    
    @try
    {
        BOOL            shouldLaunchTask    = NO;
        NSMutableArray *arguments           = [[NSMutableArray alloc] initWithObjects:self.cappuccinoProject.PBXModifierScriptPath,
                                               @"update", self.cappuccinoProject.projectPath, nil];

        for (NSString *action in self->PBXOperations)
        {
            NSArray *paths = self->PBXOperations[action];
    
            if (paths.count)
            {
                [arguments addObject:action];
                [arguments addObjectsFromArray:paths];
    
                shouldLaunchTask = YES;
            }
        }
        
        if (shouldLaunchTask)
        {
            self->task = [self->taskLauncher taskWithCommand:@"python" arguments:arguments];

            NSDictionary *result = [self->taskLauncher runTask:self->task returnType:kTaskReturnTypeStdError];
            
            if ([result[@"status"] intValue] != 0)
            {
                NSMutableDictionary *info  = [self operationInformations];
                info[@"errors"]            = result[@"message"];

                [self dispatchNotificationName:XCCPbxCreationGenerateErrorNotification userInfo:info];
            }
        }
    }
    @catch (NSException *exception)
    {
        [self dispatchNotificationName:XCCPbxCreationGenerateErrorNotification];
        DDLogVerbose(@"Pbx creation failed: %@", exception);
    }
}

@end
