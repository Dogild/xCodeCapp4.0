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
    XCCCappuccinoProjectStatusInitialized   = 0,
    XCCCappuccinoProjectStatusStopped       = 1,
    XCCCappuccinoProjectStatusLoading       = 2,
    XCCCappuccinoProjectStatusListening     = 3,
    XCCCappuccinoProjectStatusProcessing    = 4
};
typedef int XCCCappuccinoProjectStatus;


@class XCCTaskLauncher;

@interface XCCCappuccinoProject : NSObject

extern NSString * const XCCCompatibilityVersionKey;
extern NSString * const XCCCappuccinoProjectBinPathsKey;
extern NSString * const XCCProjectDidFinishLoadingNotification;
extern NSString * const XCCProjectDidStartLoadingNotification;
extern NSString * const XCCCappuccinoProjectWasListeningKey;


@property NSString                      *supportPath;
@property NSString                      *projectPath;
@property NSString                      *name;
@property NSString                      *nickname;
@property NSString                      *XcodeProjectPath;
@property NSString                      *infoPlistPath;
@property NSString                      *XcodeCappIgnorePath;
@property NSString                      *pbxModifierScriptPath;
@property NSMutableDictionary           *projectPathsForSourcePaths;
@property NSMutableArray                *ignoredPathPredicates;
@property NSDictionary                  *settings;
@property NSMutableDictionary           *errors;
@property NSString                      *objjIncludePath;
@property BOOL                          shouldProcessWithObjjWarnings;
@property BOOL                          shouldProcessWithCappLint;
@property BOOL                          shouldProcessWithObjj2ObjcSkeleton;
@property BOOL                          shouldProcessWithNib2Cib;
@property NSArray                       *environementsPaths;
@property NSString                      *ignoredPathsContent;
@property XCCCappuccinoProjectStatus    status;

+ (NSArray*)defaultEnvironmentPaths;

- (id)initWithPath:(NSString*)aPath;
- (void)updateIgnoredPath;
- (void)_init;

- (void)addOperationError:(XCCOperationError *)operationError;
- (void)removeOperationError:(XCCOperationError *)operationError;
- (void)removeAllOperationErrors;
- (void)removeOperationErrorsRelatedToSourcePath:(NSString *)aPath errorType:(int)anErrorType;

- (NSString *)projectRelativePathForPath:(NSString *)path;
- (NSString *)shadowBasePathForProjectSourcePath:(NSString *)path;
- (NSString *)sourcePathForShadowPath:(NSString *)path;
- (NSString *)projectPathForSourcePath:(NSString *)path;
- (NSString *)flattenedXcodeSupportFileNameForPath:(NSString *)aPath;

- (id)valueForSetting:(NSString*)aKey;
- (void)setValue:(id)aValue forSetting:(NSString*)aKey;
- (void)fetchProjectSettings;
- (void)saveSettings;


@end
