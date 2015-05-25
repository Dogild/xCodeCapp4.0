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
    NSString *response = [dictionary objectForKey:@"errors"];
    NSMutableArray *operationErrors = [NSMutableArray array];
    
    @try
    {
        NSArray *errors = [response propertyList];
        
        for (NSDictionary *error in errors)
        {
            if (type == XCCObjjOperationErrorType)
                [operationErrors addObject:[OperationError objjOperationErrorFromDictionary:error]];
            else
                [operationErrors addObject:[OperationError objj2ObjcSkeletonOperationErrorFromDictionary:error]];
        }
    }
    @catch (NSException *exception)
    {
        NSDictionary *error = @{@"line" : @"0",
                                @"message" : response,
                                @"path" : [dictionary objectForKey:@"sourcePath"]};
        
        if (type == XCCObjjOperationErrorType)
            [operationErrors addObject:[OperationError objjOperationErrorFromDictionary:error]];
        else
            [operationErrors addObject:[OperationError objj2ObjcSkeletonOperationErrorFromDictionary:error]];
    }
    
    return operationErrors;
}

@end
