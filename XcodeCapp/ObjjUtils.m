//
//  ObjjUtils.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/22/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "ObjjUtils.h"

@implementation ObjjUtils

+ (NSArray*)operationErrorsFromDictionary:(NSDictionary*)dictionary
{
    return [self operationErrorsFromDictionary:dictionary type:XCCObjjOperationErrorType];
}

+ (NSArray*)operationErrorsFromDictionary:(NSDictionary*)dictionary type:(XCCOperationErrorType)type
{
    NSMutableString *message = [[dictionary objectForKey:@"errors"] mutableCopy];
    NSMutableArray *operationErrors = [NSMutableArray array];
    
    [message replaceOccurrencesOfString:@"[0m" withString:@"" options:0 range:NSMakeRange(0, [message length])];
    
    @try
    {
        NSArray *errors = [message propertyList];
        
        for (NSDictionary *error in errors)
        {
            if (type == XCCObjjOperationErrorType)
                [operationErrors addObject:[XCCOperationError objjOperationErrorFromDictionary:error]];
            else
                [operationErrors addObject:[XCCOperationError objj2ObjcSkeletonOperationErrorFromDictionary:error]];
        }
    }
    @catch (NSException *exception)
    {
        NSDictionary *error = @{@"line" : @"0",
                                @"message" : message,
                                @"path" : [dictionary objectForKey:@"sourcePath"]};
        
        if (type == XCCObjjOperationErrorType)
            [operationErrors addObject:[XCCOperationError objjOperationErrorFromDictionary:error]];
        else
            [operationErrors addObject:[XCCOperationError objj2ObjcSkeletonOperationErrorFromDictionary:error]];
    }
    
    return operationErrors;
}

@end
