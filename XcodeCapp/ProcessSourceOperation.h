//
//  ProcessSourceOperation.h
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CappuccinoProject;

extern NSString * const XCCConversionDidStartNotification;
extern NSString * const XCCConversionDidGenerateErrorNotification;
extern NSString * const XCCConversionDidEndNotification;

// Status codes returned by support scripts run as tasks
enum {
    XCCStatusCodeError = 1,
    XCCStatusCodeWarning = 2
};

@interface ProcessSourceOperation : NSOperation

// sourcePath should be a path within the project (no resolved symlinks)
- (id)initWithCappuccinoProject:(CappuccinoProject *)aCappuccinoProject sourcePath:(NSString *)sourcePath;

@end
