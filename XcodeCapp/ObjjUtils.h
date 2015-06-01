//
//  ObjjUtils.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/22/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XCCOperationError.h"

@interface ObjjUtils : NSObject

+ (NSArray*)operationErrorsFromDictionary:(NSDictionary*)dictionary;
+ (NSArray*)operationErrorsFromDictionary:(NSDictionary*)dictionary type:(XCCOperationErrorType)type;

@end
