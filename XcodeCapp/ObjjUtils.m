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

+ (NSString *)cleanUpObjjXMLResponse:(NSString *)aString
{
    NSMutableString *ASCIICharacters = [NSMutableString string];

    for (NSInteger i = 32; i < 127; i++)
        [ASCIICharacters appendFormat:@"%c", (char)i];

    NSCharacterSet *set = [[NSCharacterSet characterSetWithCharactersInString:ASCIICharacters] invertedSet];

    aString = [[aString componentsSeparatedByCharactersInSet:set] componentsJoinedByString:@""];
    aString = [aString stringByReplacingOccurrencesOfString:@"[0m" withString:@""];

    return aString;
}

+ (NSArray*)operationErrorsFromDictionary:(NSDictionary*)dictionary type:(XCCOperationErrorType)type
{
    NSString        *message         = [self cleanUpObjjXMLResponse:[dictionary objectForKey:@"errors"]];
    NSMutableArray  *operationErrors = [NSMutableArray array];

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
                                @"sourcePath" : [dictionary objectForKey:@"sourcePath"]};
        
        if (type == XCCObjjOperationErrorType)
            [operationErrors addObject:[XCCOperationError objjOperationErrorFromDictionary:error]];
        else
            [operationErrors addObject:[XCCOperationError objj2ObjcSkeletonOperationErrorFromDictionary:error]];
    }
    
    return operationErrors;
}

@end
