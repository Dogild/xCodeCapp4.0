//
//  CappuccinoProject.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XCCOperationError.h"

enum {
    XCCCappuccinoProjectStatusStopped       = 0,
    XCCCappuccinoProjectStatusListening     = 1
};
typedef int XCCCappuccinoProjectStatus;


@class XCCTaskLauncher;

@interface XCCCappuccinoProject : NSObject
{
    NSMutableDictionary             *settings;
}

extern NSString * const XCCCompatibilityVersionKey;
extern NSString * const XCCCappuccinoProjectBinPathsKey;
extern NSString * const XCCCappuccinoProjectAutoStartListeningKey;

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
@property BOOL                          processing;
@property BOOL                          autoStartListening;
@property BOOL                          processObjjWarnings;
@property BOOL                          processCappLint;
@property BOOL                          processObjj2ObjcSkeleton;
@property BOOL                          processNib2Cib;
@property XCCCappuccinoProjectStatus    status;

+ (NSArray*)defaultBinaryPaths;

- (id)initWithPath:(NSString*)aPath;
- (void)reinitialize;
- (void)updateProjectPath:(NSString *)path;
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
