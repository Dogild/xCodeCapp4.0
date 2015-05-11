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

// Full path to the <project>.xcodeproj
@property NSString *xcodeProjectPath;

// Full path to .XcodeSupport/Info.plist
@property NSString *infoPlistPath;

// Full path to .xcodecapp-ignore
@property NSString *xcodecappIgnorePath;

// Environment paths used by this project
@property NSArray *environementsPaths;

// A mapping from full paths to project-relative paths
@property NSMutableDictionary *projectPathsForSourcePaths;

// A list of files name who can be processed, based on xcapp-ignore and path pf the project
@property NSMutableArray *xCodeCappTargetedFiles;

// A list of ignoredPaths from xcodecapp-ignore
@property NSMutableArray *ignoredPathPredicates;

+ (NSArray*)defaultEnvironmentPaths;

- (id)initWithPath:(NSString*)aPath;
- (void)initIgnoredPaths;
- (id)settingValueForKey:(NSString*)aKey;
- (id)defaultSettings;

- (NSString *)projectName;

- (NSString *)projectRelativePathForPath:(NSString *)path;
- (NSString *)shadowBasePathForProjectSourcePath:(NSString *)path;
- (NSString *)sourcePathForShadowPath:(NSString *)path;
- (NSString *)projectPathForSourcePath:(NSString *)path;

@end
