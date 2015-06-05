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
    NSArray         *errors = [[self cleanUpObjjXMLResponse:[dictionary objectForKey:@"errors"]] propertyList];
    NSMutableArray  *ret    = [NSMutableArray array];

    for (NSDictionary *error in errors)
    {
        XCCOperationError *operationError;

        if (type == XCCObjjOperationErrorType)
            operationError = [XCCOperationError objjOperationErrorFromDictionary:error];
        else
            operationError = [XCCOperationError objj2ObjcSkeletonOperationErrorFromDictionary:error];

        [ret addObject:operationError];
    }

    return ret;
}

@end
