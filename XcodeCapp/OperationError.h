//
//  OperationError.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

enum {
    XCCDefaultOperationErrorType            = 0,
    XCCCappLintOperationErrorType           = 1,
    XCCObjjOperationErrorType               = 2,
    XCCObjj2ObjcSkeletonOperationErrorType  = 3,
    XCCNib2CibOperationErrorType            = 4,
};
typedef int XCCOperationErrorType;

@interface OperationError : NSObject

@property (strong) NSString *fileName;
@property (strong) NSString *message;
@property (strong) NSString *command;
@property (strong) NSString *lineNumber;
@property int errorType;

+ (instancetype)defaultOperationErrorFromDictionary:(NSDictionary*)aDictionary;
+ (instancetype)nib2cibOperationErrorFromDictionary:(NSDictionary*)aDictionary;
+ (instancetype)objj2ObjcSkeletonOperationErrorFromDictionary:(NSDictionary*)aDictionary;
+ (instancetype)objjOperationErrorFromDictionary:(NSDictionary*)aDictionary;
+ (instancetype)cappLintOperationErrorFromDictionary:(NSDictionary*)aDictionary;

@end