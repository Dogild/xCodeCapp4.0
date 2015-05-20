//
//  FindSourceFilesOperation.h
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CappuccinoProject;
@class TaskManager;

extern NSString * const XCCNeedSourceToProjectPathMappingNotification;

@interface FindSourceFilesOperation : NSOperation

- (id)initWithCappuccinoProject:(CappuccinoProject *)cappuccinoProject taskManager:(TaskManager*)aTaskManager path:(NSString *)path;

@end
