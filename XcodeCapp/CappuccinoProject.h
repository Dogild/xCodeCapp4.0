//
//  CappuccinoProject.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OperationError.h"

@class TaskManager;

@interface CappuccinoProject : NSObject
{
    
}

extern NSString * const XCCCompatibilityVersionKey;
extern NSString * const XCCCappuccinoProjectBinPaths;

extern NSString * const XCCProjectDidFinishLoadingNotification;
extern NSString * const XCCProjectDidStartLoadingNotification;

// Full path to .XcodeSupport
@property NSString *supportPath;

// Full path to the Cappuccino project root directory
@property NSString *projectPath;

// Project name
@property NSString *projectName;

// Project name
@property NSString *projectSurname;

// Full path to the <project>.xcodeproj
@property NSString *xcodeProjectPath;

// Full path to .XcodeSupport/Info.plist
@property NSString *infoPlistPath;

// Full path to .xcodecapp-ignore
@property NSString *xcodecappIgnorePath;

// Full path to pbxprojModifier.py
@property NSString *pbxModifierScriptPath;

// A mapping from full paths to project-relative paths
@property NSMutableDictionary *projectPathsForSourcePaths;

// A list of files name who can be processed, based on xcapp-ignore and path pf the project
@property NSMutableArray *xCodeCappTargetedFiles;

// A list of ignoredPaths from xcodecapp-ignore
@property NSMutableArray *ignoredPathPredicates;

// Whether we are in the process of loading a project
@property BOOL isLoading;

// XcodeCapp is listening the event of this project
@property BOOL isListening;

// Whether we have loaded the project
@property BOOL isLoaded;

// Whether we are currently processing source files
@property BOOL isProcessing;

// The settings of the project
@property NSDictionary *projectSettings;

// A list of errors generated from the current batch of source processing
@property NSMutableDictionary *errors;

// Here we defined some accessors to bind them
@property NSString *objjIncludePath;
@property BOOL shouldProcessWithObjjWarnings;
@property BOOL shouldProcessWithCappLint;
@property BOOL shouldProcessWithObjj2ObjcSkeleton;
@property BOOL shouldProcessWithNib2Cib;
@property NSArray *environementsPaths;
@property NSString *ignoredPathsContent;

+ (NSArray*)defaultEnvironmentPaths;

- (id)initWithPath:(NSString*)aPath;
- (void)updateIgnoredPath;
- (void)_init;

- (void)addOperationError:(OperationError *)operationError;
- (void)removeOperationError:(OperationError *)operationError;
- (void)removeAllOperationErrors;
- (void)removeOperationErrorsRelatedToSourcePath:(NSString *)aPath errorType:(int)anErrorType;

- (NSString *)projectName;

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
