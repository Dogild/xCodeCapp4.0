//
//  TaskLauncher.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

// Type of output expected from runTaskWithLaunchPath:arguments:returnType:
enum XCCTaskReturnType {
    kTaskReturnTypeNone,
    kTaskReturnTypeStdOut,
    kTaskReturnTypeStdError,
    kTaskReturnTypeAny
};

typedef enum XCCTaskReturnType XCCTaskReturnType;

@interface XCCTaskLauncher : NSObject
{
    BOOL _isCappBuildDefined;
}

@property BOOL isValid;

@property NSMutableArray *environmentPaths;
@property NSMutableDictionary *environment;

@property NSArray *executables;
@property NSMutableDictionary *executablePaths;

- (id)initWithEnvironementPaths:(NSArray*)environementPaths;

- (BOOL)executablesAreAccessible;

- (NSTask*)taskWithCommand:(NSString *)aCommand arguments:(NSArray *)arguments;
- (NSTask*)taskWithCommand:(NSString *)aCommand arguments:(NSArray *)arguments currentDirectoryPath:(NSString*)aCurrentDirectoryPath;

- (NSDictionary *)runTaskWithCommand:(NSString *)aCommand arguments:(NSArray *)arguments returnType:(XCCTaskReturnType)returnType;
- (NSDictionary *)runTaskWithCommand:(NSString *)aCommand arguments:(NSArray *)arguments returnType:(XCCTaskReturnType)returnType currentDirectoryPath:(NSString*)aCurrentDirectoryPath;
- (NSDictionary*)runTask:(NSTask*)aTask returnType:(XCCTaskReturnType)returnType;
- (NSDictionary*)runJakeTaskWithArguments:(NSMutableArray*)arguments currentDirectoryPath:(NSString*)aCurrentDirectoryPath;

@end
