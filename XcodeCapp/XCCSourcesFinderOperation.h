//
//  FindSourceFilesOperation.h
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XCCCappuccinoProject;
@class XCCTaskLauncher;

extern NSString * const XCCNeedSourceToProjectPathMappingNotification;

@interface XCCSourcesFinderOperation : NSOperation

- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)cappuccinoProject taskLauncher:(XCCTaskLauncher*)aTaskLauncher sourcePath:(NSString *)sourcePath;

@end
