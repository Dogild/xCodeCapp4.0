//
//  OperationError.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OperationError : NSObject

@property (strong) NSString *fileName;
@property (strong) NSString *message;
@property (strong) NSString *command;
@property (strong) NSString *lineNumber;

+ (instancetype)defaultOperationErrorFromDictionary:(NSDictionary*)aDictionary;
+ (instancetype)nib2cibOperationErrorFromDictionary:(NSDictionary*)aDictionary;
+ (instancetype)objj2ObjcSkeletonOperationErrorFromDictionary:(NSDictionary*)aDictionary;

@end
