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
    XCCCappuccinoProjectStatusLoading       = 1,
    XCCCappuccinoProjectStatusListening     = 2,
    XCCCappuccinoProjectStatusProcessing    = 3
};
typedef int XCCCappuccinoProjectStatus;


@class XCCTaskLauncher;

@interface XCCCappuccinoProject : NSObject

extern NSString * const XCCCompatibilityVersionKey;
extern NSString * const XCCCappuccinoProjectBinPaths;
extern NSString * const XCCProjectDidFinishLoadingNotification;
extern NSString * const XCCProjectDidStartLoadingNotification;

@property NSString              *supportPath;
@property NSString              *projectPath;
@property NSString              *name;
@property NSString              *nickname;
@property NSString              *xcodeProjectPath;
@property NSString              *infoPlistPath;
@property NSString              *xcodecappIgnorePath;
@property NSString              *pbxModifierScriptPath;
@property NSMutableDictionary   *projectPathsForSourcePaths;
@property NSMutableArray        *ignoredPathPredicates;
@property BOOL                  isLoading;
@property BOOL                  isListening;
@property BOOL                  isLoaded;
@property BOOL                  isProcessing;
@property NSDictionary          *settings;
@property NSMutableDictionary   *errors;
@property NSString              *objjIncludePath;
@property BOOL                  shouldProcessWithObjjWarnings;
@property BOOL                  shouldProcessWithCappLint;
@property BOOL                  shouldProcessWithObjj2ObjcSkeleton;
@property BOOL                  shouldProcessWithNib2Cib;
@property NSArray               *environementsPaths;
@property NSString              *ignoredPathsContent;

+ (NSArray*)defaultEnvironmentPaths;

- (id)initWithPath:(NSString*)aPath;
- (void)updateIgnoredPath;
- (void)_init;

- (void)addOperationError:(XCCOperationError *)operationError;
- (void)removeOperationError:(XCCOperationError *)operationError;
- (void)removeAllOperationErrors;
- (void)removeOperationErrorsRelatedToSourcePath:(NSString *)aPath errorType:(int)anErrorType;

- (NSString *)name;

- (NSString *)projectRelativePathForPath:(NSString *)path;
- (NSString *)shadowBasePathForProjectSourcePath:(NSString *)path;
- (NSString *)sourcePathForShadowPath:(NSString *)path;
- (NSString *)projectPathForSourcePath:(NSString *)path;
- (NSString *)flattenedXcodeSupportFileNameForPath:(NSString *)aPath;

- (id)settingValueForKey:(NSString*)aKey;
- (NSMutableDictionary*)defaultSettings;
- (NSMutableDictionary*)currentSettings;
- (void)updateSettingValue:(id)aValue forKey:(NSString*)aKey;
- (void)fetchProjectSettings;

@end
