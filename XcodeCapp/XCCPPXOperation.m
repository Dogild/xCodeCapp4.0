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

NSString * const XCCPbxCreationDidStartNotification = @"XCCPbxCreationDidStartNotification";
NSString * const XCCPbxCreationGenerateErrorNotification = @"XCCPbxCreationDidGenerateErrorNotification";
NSString * const XCCPbxCreationDidEndNotification = @"XCCPbxCreationDidEndNotification";


@implementation XCCPPXOperation

#pragma mark - Initialization

- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)aCappuccinoProject taskLauncher:(XCCTaskLauncher*)aTaskLauncher PBXOperations:(NSMutableDictionary *)pbxOperations
{
    if (self = [super initWithCappuccinoProject:aCappuccinoProject taskLauncher:aTaskLauncher])
    {
        self.PBXOperations          = [pbxOperations mutableCopy];
        self.operationDescription   = self.cappuccinoProject.projectPath;
        self.operationName          = @"Updating the Xcode project";
    }
    
    return self;
}


#pragma mark - NSOperation API

- (void)main
{
    if (self.isCancelled)
        return;

    [self dispatchNotificationName:XCCPbxCreationDidStartNotification];

    DDLogVerbose(@"Pbx creation started: %@", self.cappuccinoProject.projectPath);
    
    @try
    {
        BOOL            shouldLaunchTask    = NO;
        NSMutableArray *arguments           = [[NSMutableArray alloc] initWithObjects:self.cappuccinoProject.PBXModifierScriptPath,
                                               @"update", self.cappuccinoProject.projectPath, nil];

        for (NSString *action in self.PBXOperations)
        {
            NSArray *paths = self.PBXOperations[action];
    
            if (paths.count)
            {
                [arguments addObject:action];
                [arguments addObjectsFromArray:paths];
    
                shouldLaunchTask = YES;
            }
        }
        
        if (!shouldLaunchTask)
        {
            NSDictionary *result = [self->taskLauncher runTaskWithCommand:@"python" arguments:arguments returnType:kTaskReturnTypeStdError];
            
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
    @finally
    {
        [self dispatchNotificationName:XCCPbxCreationDidEndNotification];

        DDLogVerbose(@"Pbx creation ended: %@", self.cappuccinoProject.projectPath);
    }
}

@end
