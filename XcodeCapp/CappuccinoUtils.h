//
//  CappuccinoUtils.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/7/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CappuccinoUtils : NSObject

+ (BOOL)isObjjFile:(NSString *)path;
+ (BOOL)isXibFile:(NSString *)path;
+ (NSArray *)parseIgnorePaths:(NSArray *)paths;
+ (BOOL)pathMatchesIgnoredPaths:(NSString*)aPath cappuccinoProjectIgnoredPathPredicates:(NSMutableArray*)cappuccinoProjectIgnoredPathPredicates;
+ (BOOL)shouldIgnoreDirectoryNamed:(NSString *)filename;

@end
