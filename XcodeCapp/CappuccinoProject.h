//
//  CappuccinoProject.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

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

// Full path to the <project>.xcodeproj
@property NSString *xcodeProjectPath;

// Full path to .XcodeSupport/Info.plist
@property NSString *infoPlistPath;

// Full path to .xcodecapp-ignore
@property NSString *xcodecappIgnorePath;

// A mapping from full paths to project-relative paths
@property NSMutableDictionary *projectPathsForSourcePaths;

// A list of files name who can be processed, based on xcapp-ignore and path pf the project
@property NSMutableArray *xCodeCappTargetedFiles;

// A list of ignoredPaths from xcodecapp-ignore
@property NSMutableArray *ignoredPathPredicates;

// Here we defined some accessors to bind them
@property NSString *objjIncludePath;
@property BOOL shouldProcessWithObjjWarnings;
@property BOOL shouldProcessWithCappLint;
@property BOOL shouldProcessWithObjj2ObjcSkeleton;
@property BOOL shouldProcessWithNib2Cib;
@property NSArray *environementsPaths;


+ (NSArray*)defaultEnvironmentPaths;

- (id)initWithPath:(NSString*)aPath;
- (void)initIgnoredPaths;
- (void)initEnvironmentPaths;

- (NSString *)projectName;

- (NSString *)projectRelativePathForPath:(NSString *)path;
- (NSString *)shadowBasePathForProjectSourcePath:(NSString *)path;
- (NSString *)sourcePathForShadowPath:(NSString *)path;
- (NSString *)projectPathForSourcePath:(NSString *)path;

- (id)settingValueForKey:(NSString*)aKey;
- (id)defaultSettings;
- (void)saveSettings;
- (void)updateSettingValue:(id)aValue forKey:(NSString*)aKey;
- (void)fetchProjectSettings;;

@end
