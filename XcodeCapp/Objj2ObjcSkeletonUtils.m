//
//  Objj2ObjcSkeletonUtils.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/22/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "Objj2ObjcSkeletonUtils.h"

#import "OperationError.h"

@implementation Objj2ObjcSkeletonUtils

+ (NSArray*)operationErrorsFromDictionary:(NSDictionary*)dictionary
{
    NSString *response = [dictionary objectForKey:@"errors"];
    NSMutableArray *operationErrors = [NSMutableArray array];
    
    @try
    {
        NSArray *errors = [response propertyList];
        
        for (NSDictionary *error in errors)
        {
            [operationErrors addObject:[OperationError objj2ObjcSkeletonOperationErrorFromDictionary:error]];
        }
    }
    @catch (NSException *exception)
    {
        NSDictionary *error = @{@"line" : @"0",
                                @"message" : response,
                                @"path" : [dictionary objectForKey:@"sourcePath"]};
        
        [operationErrors addObject:[OperationError objj2ObjcSkeletonOperationErrorFromDictionary:error]];
    }
    
    return operationErrors;
}

@end
