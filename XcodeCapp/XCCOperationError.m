//
//  OperationError.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCOperationError.h"

static NSCharacterSet * XCCOperationErrorNonASCIICharactersSet;

NSString * _cleanUpXMLString(NSString * aString)
{
    if (!XCCOperationErrorNonASCIICharactersSet)
    {
        NSMutableString *ASCIICharacters = [NSMutableString string];

        for (NSInteger i = 32; i < 127; i++)
            [ASCIICharacters appendFormat:@"%c", (char)i];

        XCCOperationErrorNonASCIICharactersSet = [[NSCharacterSet characterSetWithCharactersInString:ASCIICharacters] invertedSet];

    }
    aString = [[aString componentsSeparatedByCharactersInSet:XCCOperationErrorNonASCIICharactersSet] componentsJoinedByString:@""];
    aString = [aString stringByReplacingOccurrencesOfString:@"[0m" withString:@""];

    return aString;
}



@implementation XCCOperationError

+ (instancetype)operationErrorWithInfo:(NSDictionary*)info type:(int)type
{
    XCCOperationError *operationError = [self new];

    operationError.fileName     = info[@"sourcePath"];
    operationError.message      = info[@"errors"];
    operationError.errorType    = type;

    switch (type)
    {
        case XCCObjj2ObjcSkeletonOperationErrorType:
            operationError.command      = @"objj2objc2skeleton";
            operationError.lineNumber   = info[@"line"];
            break;

        case XCCObjjOperationErrorType:
            operationError.command      = @"objj";
            operationError.lineNumber   = info[@"line"];
            break;

        case XCCNib2CibOperationErrorType:
            operationError.command      = @"nib2cib";

        case XCCCappLintOperationErrorType:
            operationError.command      = @"capp_lint";
            operationError.lineNumber   = info[@"line"];
            break;
    }

    return operationError;
}

+ (NSArray*)operationErrorsFromObjj2ObjcSkeletonInfo:(NSDictionary*)info
{
    NSArray         *errors = [_cleanUpXMLString(info[@"errors"]) propertyList];
    NSMutableArray  *ret    = [NSMutableArray array];

    for (NSDictionary *error in errors)
        [ret addObject:[XCCOperationError operationErrorWithInfo:error type:XCCObjj2ObjcSkeletonOperationErrorType]];
    
    return ret;
}

+ (NSArray*)operationErrorsFromObjjInfo:(NSDictionary*)info
{
    NSArray         *errors = [_cleanUpXMLString(info[@"errors"]) propertyList];
    NSMutableArray  *ret    = [NSMutableArray array];

    for (NSDictionary *error in errors)
        [ret addObject:[XCCOperationError operationErrorWithInfo:error type:XCCObjjOperationErrorType]];

    return ret;
}

+ (NSArray*)operationErrorsFromCappLintInfo:(NSDictionary *)info
{
    NSString        *response           = [info objectForKey:@"errors"];
    NSString        *sourcePath         = [info objectForKey:@"sourcePath"];
    NSMutableArray  *operationErrors    = [NSMutableArray array];
    NSMutableArray  *errors             = [NSMutableArray arrayWithArray:[response componentsSeparatedByString:@"\n\n"]];

    // We need to remove the first object who is the number of errors and the last object who is an empty line
    [errors removeLastObject];
    [errors removeObjectAtIndex:0];

    for (int i = 0; i < [errors count]; i++)
    {
        NSString            *line;
        NSMutableString     *error      = (NSMutableString*)[errors objectAtIndex:i];
        NSString            *firstChar  = [NSString stringWithFormat:@"%c" ,[error characterAtIndex:0]];

        if ([[NSScanner scannerWithString:firstChar] scanInt:nil])
            error = (NSMutableString*)[NSString stringWithFormat:@"%@:%@", sourcePath, error];

        NSInteger positionOfFirstColon = [error rangeOfString:@":"].location;

        NSString *errorWithoutPath = [error substringFromIndex:(positionOfFirstColon + 1)];
        NSInteger positionOfSecondColon = [errorWithoutPath rangeOfString:@":"].location;
        line = [errorWithoutPath substringToIndex:positionOfSecondColon];

        NSString *message = [NSString stringWithFormat:@"Code style issue at line %@ of file %@:\n%@", line, sourcePath.lastPathComponent, errorWithoutPath];

        NSDictionary *info = @{@"line": line,
                               @"message": message,
                               @"sourcePath": sourcePath};

        XCCOperationError *operationError = [XCCOperationError operationErrorWithInfo:info type:XCCCappLintOperationErrorType];

        [operationErrors addObject:operationError];
    }

    return operationErrors;
}

+ (XCCOperationError *)operationErrorFromNib2CibInfo:(NSDictionary*)info
{
    return [XCCOperationError operationErrorWithInfo:info type:XCCNib2CibOperationErrorType];
}

- (BOOL)isEqualTo:(XCCOperationError*)object
{
    return object.errorType == self.errorType && [object.fileName isEqualToString:self.fileName];
}

@end
