//
//  OperationError.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCOperationError.h"

@implementation XCCOperationError

@synthesize message = _message;

+ (instancetype)defaultOperationErrorFromDictionary:(NSDictionary*)aDictionary
{
    XCCOperationError *operationError = [[self alloc] init];
    
    operationError.fileName = [aDictionary objectForKey:@"sourcePath"];
    operationError.message = [aDictionary objectForKey:@"errors"];
    operationError.errorType = XCCDefaultOperationErrorType;
    
    return operationError;
}

+ (instancetype)nib2cibOperationErrorFromDictionary:(NSDictionary*)aDictionary
{
    XCCOperationError *operationError = [[self alloc] init];
    
    operationError.fileName = [aDictionary objectForKey:@"sourcePath"];
    operationError.message = [aDictionary objectForKey:@"errors"];
    operationError.errorType = XCCNib2CibOperationErrorType;
    operationError.command = @"nib2cib";
    
    return operationError;
}

+ (instancetype)objj2ObjcSkeletonOperationErrorFromDictionary:(NSDictionary*)aDictionary
{
    XCCOperationError *operationError = [[self alloc] init];
    
    operationError.fileName = [aDictionary objectForKey:@"path"];
    operationError.message = [aDictionary objectForKey:@"message"];
    operationError.lineNumber = [aDictionary objectForKey:@"line"];
    operationError.errorType = XCCObjj2ObjcSkeletonOperationErrorType;
    operationError.command = @"objj2objcskeleton";
    
    return operationError;
}

+ (instancetype)objjOperationErrorFromDictionary:(NSDictionary*)aDictionary
{
    XCCOperationError *operationError = [[self alloc] init];
    
    operationError.fileName = [aDictionary objectForKey:@"path"];
    operationError.message = [aDictionary objectForKey:@"message"];
    operationError.lineNumber = [aDictionary objectForKey:@"line"];
    operationError.errorType = XCCObjjOperationErrorType;
    operationError.command = @"objj";
    
    return operationError;
}

+ (instancetype)cappLintOperationErrorFromDictionary:(NSDictionary*)aDictionary
{
    XCCOperationError *operationError = [[self alloc] init];
    
    operationError.fileName = [aDictionary objectForKey:@"path"];
    operationError.message = [aDictionary objectForKey:@"message"];
    operationError.lineNumber = [aDictionary objectForKey:@"line"];
    operationError.errorType = XCCCappLintOperationErrorType;
    operationError.command = @"capp_lint";
    
    return operationError;
}

- (BOOL)isEqualTo:(XCCOperationError*)object
{
    return object.errorType == self.errorType && [object.fileName isEqualToString:self.fileName];
}

- (NSString *)message
{
    
    NSInteger i = 0;
    
    while ((i < [_message length]) && [[NSCharacterSet newlineCharacterSet] characterIsMember:[_message characterAtIndex:i]]) {
        i++;
    }
    
    return [_message substringFromIndex:i];
}
@end