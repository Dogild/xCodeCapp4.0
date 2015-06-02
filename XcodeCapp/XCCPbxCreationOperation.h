//
//  XCCPbxCreationOperation.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 6/2/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XCCCappuccinoProject;
@class XCCTaskLauncher;

@interface XCCPbxCreationOperation : NSOperation

extern NSString * const XCCPbxCreationDidStartNotification;
extern NSString * const XCCPbxCreationGenerateErrorNotification;
extern NSString * const XCCPbxCreationDidEndNotification;

- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)aCappuccinoProject taskLauncher:(XCCTaskLauncher*)aTaskLauncher pbxOperations:(NSMutableDictionary *)pbxOperations;

@end