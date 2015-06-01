//
//  ProcessSourceOperation.h
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XCCCappuccinoProject;
@class TaskManager;

extern NSString * const XCCConversionDidStartNotification;
extern NSString * const XCCConversionDidGenerateErrorNotification;
extern NSString * const XCCConversionDidEndNotification;
extern NSString * const XCCObjjDidStartNotification;
extern NSString * const XCCObjjDidEndNotification;
extern NSString * const XCCCappLintDidStartNotification;
extern NSString * const XCCCappLintDidEndNotification;
extern NSString * const XCCObjj2ObjcSkeletonDidStartNotification;
extern NSString * const XCCObjj2ObjcSkeletonDidEndNotification;
extern NSString * const XCCNib2CibDidStartNotification;
extern NSString * const XCCNib2CibDidEndNotification;
extern NSString * const XCCObjjDidGenerateErrorNotification;
extern NSString * const XCCCappLintDidGenerateErrorNotification;
extern NSString * const XCCObjj2ObjcSkeletonDidGenerateErrorNotification;
extern NSString * const XCCNib2CibDidGenerateErrorNotification;
extern NSString * const XCCConversionDidGenerateCancelNotification;

@interface XCCCSourceProcessingOperation : NSOperation

@property NSTask *task;

// sourcePath should be a path within the project (no resolved symlinks)
- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)aCappuccinoProject taskManager:(TaskManager*)aTaskManager sourcePath:(NSString *)sourcePath;
- (NSString *)operationName;
- (NSString *)operationDescription;
@end
