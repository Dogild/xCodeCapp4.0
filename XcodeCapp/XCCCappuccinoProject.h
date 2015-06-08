//
//  CappuccinoProject.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XCCOperationError.h"

@class XCCTaskLauncher;

enum {
    XCCCappuccinoProjectStatusStopped       = 0,
    XCCCappuccinoProjectStatusListening     = 1
};
typedef int XCCCappuccinoProjectStatus;




extern NSString * const XCCCompatibilityVersionKey;
extern NSString * const XCCCappuccinoProjectBinPathsKey;
extern NSString * const XCCCappuccinoProjectPreviousStatusKey;


@interface XCCCappuccinoProject : NSObject
{
    NSMutableDictionary             *settings;
}

@property NSString                      *supportPath;
@property NSString                      *projectPath;
@property NSString                      *name;
@property NSString                      *nickname;
@property NSString                      *XcodeProjectPath;
@property NSString                      *settingsPath;
@property NSString                      *XcodeCappIgnorePath;
@property NSNumber                      *lastEventID;
@property NSString                      *PBXModifierScriptPath;
@property NSMutableDictionary           *projectPathsForSourcePaths;
@property NSMutableArray                *ignoredPathPredicates;
@property NSMutableDictionary           *errors;
@property NSInteger                     numberOfErrors;
@property NSString                      *version;
@property NSString                      *errorsCountString;
@property NSString                      *objjIncludePath;
@property NSMutableArray                *binaryPaths;
@property NSString                      *XcodeCappIgnoreContent;
@property BOOL                          processObjjWarnings;
@property BOOL                          processCappLint;
@property BOOL                          processObjj2ObjcSkeleton;
@property BOOL                          processNib2Cib;
@property XCCCappuccinoProjectStatus    status;
@property XCCCappuccinoProjectStatus    previousSavedStatus;

+ (BOOL)isObjjFile:(NSString *)path;
+ (BOOL)isXibFile:(NSString *)path;
+ (BOOL)isCibFile:(NSString *)path;
+ (BOOL)isHeaderFile:(NSString *)path;
+ (BOOL)isXCCIgnoreFile:(NSString *)path cappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject;
+ (BOOL)isSourceFile:(NSString *)path cappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject;
+ (BOOL)pathMatchesIgnoredPaths:(NSString*)aPath cappuccinoProjectIgnoredPathPredicates:(NSMutableArray*)cappuccinoProjectIgnoredPathPredicates;
+ (BOOL)shouldIgnoreDirectoryNamed:(NSString *)filename;
+ (void)notifyUserWithTitle:(NSString *)aTitle message:(NSString *)aMessage;
+ (void)watchSymlinkedDirectoriesAtPath:(NSString *)projectPath pathsToWatch:(NSMutableArray *)pathsToWatch cappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject;
+ (NSArray *)defaultBinaryPaths;
+ (NSArray *)parseIgnorePaths:(NSArray *)paths basePath:(NSString *)basePath;
+ (NSArray *)getPathsToWatchForCappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject;

- (id)initWithPath:(NSString*)aPath;
- (void)reinitialize;
- (void)addOperationError:(XCCOperationError *)operationError;
- (void)removeOperationError:(XCCOperationError *)operationError;
- (void)removeAllOperationErrors;
- (void)removeOperationErrorsRelatedToSourcePath:(NSString *)aPath errorType:(int)anErrorType;
- (void)saveSettings;
- (void)reloadXcodeCappIgnoreFile;

- (NSString *)projectRelativePathForPath:(NSString *)path;
- (NSString *)shadowBasePathForProjectSourcePath:(NSString *)path;
- (NSString *)sourcePathForShadowPath:(NSString *)path;
- (NSString *)projectPathForSourcePath:(NSString *)path;
- (NSString *)flattenedXcodeSupportFileNameForPath:(NSString *)aPath;

@end
