//
//  ObjjUtils.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/22/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "ObjjUtils.h"

static NSCharacterSet * XCCObjjUtilsNonASCIICharactersSet;

@implementation ObjjUtils

+ (void)initialize
{
    NSMutableString *ASCIICharacters = [NSMutableString string];

    for (NSInteger i = 32; i < 127; i++)
        [ASCIICharacters appendFormat:@"%c", (char)i];

    XCCObjjUtilsNonASCIICharactersSet = [[NSCharacterSet characterSetWithCharactersInString:ASCIICharacters] invertedSet];

}
+ (NSArray*)operationErrorsFromDictionary:(NSDictionary*)dictionary
{
    return [self operationErrorsFromDictionary:dictionary type:XCCObjjOperationErrorType];
}

+ (NSString *)_cleanUpXMLString:(NSString *)aString
{

    aString = [[aString componentsSeparatedByCharactersInSet:XCCObjjUtilsNonASCIICharactersSet] componentsJoinedByString:@""];
    aString = [aString stringByReplacingOccurrencesOfString:@"[0m" withString:@""];

    return aString;
}

+ (NSArray*)operationErrorsFromDictionary:(NSDictionary*)dictionary type:(XCCOperationErrorType)type
{
    NSArray         *errors = [[self _cleanUpXMLString:dictionary[@"errors"]] propertyList];
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
