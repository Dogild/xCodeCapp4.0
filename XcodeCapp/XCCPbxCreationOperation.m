//
//  XCCPbxCreationOperation.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 6/2/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCPbxCreationOperation.h"
#import "XCCCappuccinoProject.h"
#import "XCCTaskLauncher.h"

NSString * const XCCPbxCreationDidStartNotification = @"XCCPbxCreationDidStartNotification";
NSString * const XCCPbxCreationGenerateErrorNotification = @"XCCPbxCreationDidGenerateErrorNotification";
NSString * const XCCPbxCreationDidEndNotification = @"XCCPbxCreationDidEndNotification";

@interface XCCPbxCreationOperation ()

@property XCCTaskLauncher *taskLauncher;
@property NSMutableDictionary *pbxOperations;
@end

@implementation XCCPbxCreationOperation


- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)aCappuccinoProject taskLauncher:(XCCTaskLauncher*)aTaskLauncher pbxOperations:(NSMutableDictionary *)pbxOperations
{
    self = [super init];
    
    if (self)
    {
        self.taskLauncher = aTaskLauncher;
        self.cappuccinoProject = aCappuccinoProject;
        self.pbxOperations = [pbxOperations mutableCopy];
    }
    
    return self;
}

- (NSString*)operationName
{
    return @"Updating the pbx file of the project";
}

- (NSString*)operationDescription
{
    return self.cappuccinoProject.projectPath;
}

- (void)main
{
    if (self.isCancelled)
        return;
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    NSDictionary *info = @{@"cappuccinoProject":self.cappuccinoProject,
                           @"operation":self};
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [center postNotificationName:XCCPbxCreationDidStartNotification object:self userInfo:info];
    });
    DDLogVerbose(@"Pbx creation started: %@", self.cappuccinoProject.projectPath);
    
    @try
    {
        NSMutableArray *arguments = [[NSMutableArray alloc] initWithObjects:self.cappuccinoProject.pbxModifierScriptPath, @"update", self.cappuccinoProject.projectPath, nil];
        
        BOOL shouldLaunchTask = NO;
    
        for (NSString *action in self.pbxOperations)
        {
            NSArray *paths = self.pbxOperations[action];
    
            if (paths.count)
            {
                [arguments addObject:action];
                [arguments addObjectsFromArray:paths];
    
                shouldLaunchTask = YES;
            }
        }
        
        if (shouldLaunchTask)
        {
            NSDictionary *result = [self.taskLauncher runTaskWithCommand:@"python" arguments:arguments returnType:kTaskReturnTypeStdError];
            
            if ([result[@"status"] intValue] != 0)
            {
                NSMutableDictionary *errorInfo = [info mutableCopy];
                errorInfo[@"errors"] = result[@"message"];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [center postNotificationName:XCCPbxCreationGenerateErrorNotification object:self userInfo:errorInfo];
                });
            }
        }
    }
    @catch (NSException *exception)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [center postNotificationName:XCCPbxCreationGenerateErrorNotification object:self userInfo:info];
        });
        
        DDLogVerbose(@"Pbx creation failed: %@", exception);
    }
    @finally
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [center postNotificationName:XCCPbxCreationDidEndNotification object:self userInfo:info];
        });
        
        DDLogVerbose(@"Pbx creation ended: %@", self.cappuccinoProject.projectPath);
    }
}

@end
