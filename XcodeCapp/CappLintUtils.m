//
//  CappLintUtils.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/22/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "CappLintUtils.h"
#import "XCCOperationError.h"

@implementation CappLintUtils

+ (NSArray*)operationErrorsFromDictionary:(NSDictionary*)dictionary
{
    NSString *response = [dictionary objectForKey:@"errors"];
    NSString *sourcePath = [dictionary objectForKey:@"sourcePath"];
    
    NSMutableArray *operationErrors = [NSMutableArray array];
    
    NSMutableArray *errors = [NSMutableArray arrayWithArray:[response componentsSeparatedByString:@"\n\n"]];
    
    // We need to remove the first object who is the number of errors and the last object who is an empty line
    [errors removeLastObject];
    [errors removeObjectAtIndex:0];
    
    for (int i = 0; i < [errors count]; i++)
    {
        NSMutableString *error = (NSMutableString*)[errors objectAtIndex:i];
        NSString *line;
        NSString *firstCaract = [NSString stringWithFormat:@"%c" ,[error characterAtIndex:0]];
        
        if ([[NSScanner scannerWithString:firstCaract] scanInt:nil])
            error = (NSMutableString*)[NSString stringWithFormat:@"%@:%@", sourcePath, error];
        
        NSInteger positionOfFirstColon = [error rangeOfString:@":"].location;
        
        NSString *errorWithoutPath = [error substringFromIndex:(positionOfFirstColon + 1)];
        NSInteger positionOfSecondColon = [errorWithoutPath rangeOfString:@":"].location;
        line = [errorWithoutPath substringToIndex:positionOfSecondColon];
        
        NSString *messageError = [NSString stringWithFormat:@"Code style issue at line %@ of file %@:\n%@", line, sourcePath.lastPathComponent, errorWithoutPath];
        
        NSDictionary *dict = @{@"line": line,
                               @"message": messageError,
                               @"sourcePath": sourcePath};
        
        XCCOperationError *operationError = [XCCOperationError cappLintOperationErrorFromDictionary:dict];
        
        [operationErrors addObject:operationError];
    }
    
    return operationErrors;
}

@end
