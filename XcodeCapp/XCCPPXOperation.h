//
//  XCCPbxCreationOperation.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 6/2/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XCCAbstractOperation.h"

@class XCCCappuccinoProject;
@class XCCTaskLauncher;

extern NSString * const XCCPBXOperationDidStartNotification;
extern NSString * const XCCPbxCreationGenerateErrorNotification;
extern NSString * const XCCPBXOperationDidEndNotification;

@interface XCCPPXOperation : XCCAbstractOperation
{
    NSMutableDictionary *PBXOperations;
    NSTask              *task;
}

- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)aCappuccinoProject taskLauncher:(XCCTaskLauncher*)aTaskLauncher;
- (void)registerPathToAddInPBX:(NSString *)path;
- (void)registerPathToRemoveFromPBX:(NSString *)path;
@end
