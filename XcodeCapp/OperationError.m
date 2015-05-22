//
//  OperationError.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "OperationError.h"

@implementation OperationError

+ (instancetype)defaultOperationErrorFromDictionary:(NSDictionary*)aDictionary
{
    OperationError *operationError = [[self alloc] init];
    
    operationError.fileName = [aDictionary objectForKey:@"sourcePath"];
    operationError.message = [aDictionary objectForKey:@"errors"];
    
    return operationError;
}

+ (instancetype)nib2cibOperationErrorFromDictionary:(NSDictionary*)aDictionary
{
    OperationError *operationError = [[self alloc] init];
    
    operationError.fileName = [aDictionary objectForKey:@"sourcePath"];
    operationError.message = [aDictionary objectForKey:@"errors"];
    
    return operationError;
}

+ (instancetype)objj2ObjcSkeletonOperationErrorFromDictionary:(NSDictionary*)aDictionary
{
    OperationError *operationError = [[self alloc] init];
    
    operationError.fileName = [aDictionary objectForKey:@"path"];
    operationError.message = [aDictionary objectForKey:@"message"];
    operationError.lineNumber = [aDictionary objectForKey:@"line"];
    
    return operationError;
}

@end
