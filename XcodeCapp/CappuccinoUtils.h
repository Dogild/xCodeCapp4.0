//
//  CappuccinoUtils.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/7/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XCCCappuccinoProject;
@class CappuccinoError;


@interface CappuccinoUtils : NSObject
+ (NSArray *)defaultIgnoredPaths;
+ (BOOL)isObjjFile:(NSString *)path;
+ (BOOL)isXibFile:(NSString *)path;
+ (BOOL)isCibFile:(NSString *)path;
+ (BOOL)isHeaderFile:(NSString *)path;
+ (BOOL)isXCCIgnoreFile:(NSString *)path cappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject;
+ (BOOL)isSourceFile:(NSString *)path cappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject;
+ (NSArray *)parseIgnorePaths:(NSArray *)paths;
+ (BOOL)pathMatchesIgnoredPaths:(NSString*)aPath cappuccinoProjectIgnoredPathPredicates:(NSMutableArray*)cappuccinoProjectIgnoredPathPredicates;
+ (BOOL)shouldIgnoreDirectoryNamed:(NSString *)filename;

+ (void)notifyUserWithTitle:(NSString *)aTitle message:(NSString *)aMessage;

+ (NSArray *)getPathsToWatchForCappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject;

+ (void)watchSymlinkedDirectoriesAtPath:(NSString *)projectPath pathsToWatch:(NSMutableArray *)pathsToWatch cappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject;

@end
