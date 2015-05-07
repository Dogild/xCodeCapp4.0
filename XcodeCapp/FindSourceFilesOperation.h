//
//  FindSourceFilesOperation.h
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CappuccinoProject;

extern NSString * const XCCNeedSourceToProjectPathMappingNotification;

@interface FindSourceFilesOperation : NSOperation

- (id)initWithCappuccinoProject:(CappuccinoProject *)cappuccinoProject path:(NSString *)path;

@end
