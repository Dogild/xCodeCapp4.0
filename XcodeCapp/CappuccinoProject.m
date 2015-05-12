//
//  CappuccinoProject.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#include <fcntl.h>

#import "CappuccinoProject.h"
#import "CappuccinoUtils.h"

// We replace "/" in a path with this. It looks like "/",
// but is actually an obscure Unicode character we hope no one uses in a filename.
static NSString * const XCCSlashReplacement = @"∕";  // DIVISION SLASH, Unicode: U+2215

// Where we put the generated Cocoa class files
static NSString * const XCCSupportFolderName = @".XcodeSupport";

// Project should process capp lint or not
static NSString * const XCCCappuccinoProcessCappLint = @"XCCCappuccinoProcessCappLint";

// Project should process capp lint or not
static NSString * const XCCCappuccinoProcessObjj = @"XCCCappuccinoProcessObjj";

// Project should process nib2cib or not
static NSString * const XCCCappuccinoProcessNib2Cib = @"XCCCappuccinoProcessNib2Cib";

// Project should process objj2objcskeleton or not
static NSString * const XCCCappuccinoProcessObjj2ObjcSkeleton = @"XCCCappuccinoProcessObjj2ObjcSkeleton";

// We store a compatibility version in .XcodeSupport/Info.plist.
// If the version is less than the version in XcodeCapp's Info.plist, we regenerate .XcodeSupport.
NSString * const XCCCompatibilityVersionKey = @"XCCCompatibilityVersion";

// Bin paths used by this project
NSString * const XCCCappuccinoProjectBinPaths = @"XCCCappuccinoProjectBinPaths";

// Default environement paths
static NSArray * XCCDefaultEnvironmentPaths;

// Default info plist XCCDefaultInfoPlistConfigurations
static NSDictionary* XCCDefaultInfoPlistConfigurations;

NSString * const XCCProjectDidFinishLoadingNotification = @"XCCProjectDidFinishLoadingNotification";
NSString * const XCCProjectDidStartLoadingNotification = @"XCCProjectDidStartLoadingNotification";

@interface CappuccinoProject ()

@property NSFileManager *fm;

// A queue for threaded operations to perform
@property NSOperationQueue *operationQueue;

@property NSDictionary *projectSettings;

@end


@implementation CappuccinoProject

#pragma mark - Class methods

+ (void)initialize
{
    if (self != [CappuccinoProject class])
        return;
    
    XCCDefaultEnvironmentPaths = [NSArray arrayWithObjects:@"/usr/local/narwhal/bin", @"~/narwhal/bin", nil];
    
    NSNumber *appCompatibilityVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey];
    
    XCCDefaultInfoPlistConfigurations = @{XCCCompatibilityVersionKey: appCompatibilityVersion,
                                          XCCCappuccinoProcessCappLint: @YES,
                                          XCCCappuccinoProcessObjj: @YES,
                                          XCCCappuccinoProcessNib2Cib: @YES,
                                          XCCCappuccinoProcessObjj2ObjcSkeleton: @YES,
                                          XCCCappuccinoProjectBinPaths: XCCDefaultEnvironmentPaths};
}

+ (NSArray*)defaultEnvironmentPaths
{
    return XCCDefaultEnvironmentPaths;
}

#pragma mark - Init methods

- (id)initWithPath:(NSString*)aPath
{
    self = [super init];
    
    if (self)
    {
        self.fm = [NSFileManager defaultManager];
        self.projectPath = aPath;
        self.xcodecappIgnorePath = [self.projectPath stringByAppendingPathComponent:@".xcodecapp-ignore"];
        
        NSString *projectName = [self.projectPath.lastPathComponent stringByAppendingString:@".xcodeproj"];
        
        self.xcodeProjectPath = [self.projectPath stringByAppendingPathComponent:projectName];
        self.supportPath = [self.projectPath stringByAppendingPathComponent:XCCSupportFolderName];
        self.infoPlistPath = [self.supportPath stringByAppendingPathComponent:@"Info.plist"];
        
        self.projectSettings = [NSDictionary dictionaryWithContentsOfFile:self.infoPlistPath];
        
        [self _init];
    }
    
    return self;
}

- (void)_init
{
    self.projectPathsForSourcePaths = [NSMutableDictionary new];
}

- (void)initIgnoredPaths
{
    self.ignoredPathPredicates = [NSMutableArray new];
    
    if ([self.fm fileExistsAtPath:self.xcodecappIgnorePath])
    {
        NSString *ignoreFileContent = [NSString stringWithContentsOfFile:self.xcodecappIgnorePath encoding:NSUTF8StringEncoding error:nil];
        NSArray *ignoredPatterns = [ignoreFileContent componentsSeparatedByString:@"\n"];
        NSArray *parsedPaths = [CappuccinoUtils parseIgnorePaths:ignoredPatterns];
        [self.ignoredPathPredicates addObjectsFromArray:parsedPaths];
    }
    
    DDLogVerbose(@"Ignoring file paths: %@", self.ignoredPathPredicates);
}

- (void)fetchProjectSettings
{
    self.projectSettings = [NSDictionary dictionaryWithContentsOfFile:self.infoPlistPath];
}

- (id)settingValueForKey:(NSString*)aKey
{
    return [self.projectSettings valueForKey:aKey];
}

- (id)defaultSettings
{
    return XCCDefaultInfoPlistConfigurations;
}


#pragma mark path methods

- (NSString *)projectName
{
    return [self.projectPath lastPathComponent];
}

- (NSString *)projectRelativePathForPath:(NSString *)path
{
    return [path substringFromIndex:self.projectPath.length + 1];
}

- (NSString *)projectPathForSourcePath:(NSString *)path
{
    NSString *base = path.stringByDeletingLastPathComponent;
    NSString *projectPath = self.projectPathsForSourcePaths[base];
    
    return projectPath ? [projectPath stringByAppendingPathComponent:path.lastPathComponent] : path;
}

#pragma mark - Shadow Files Management

- (NSString *)shadowBasePathForProjectSourcePath:(NSString *)path
{
    if (path.isAbsolutePath)
        path = [self projectRelativePathForPath:path];
    
    NSString *filename = [path.stringByDeletingPathExtension stringByReplacingOccurrencesOfString:@"/" withString:XCCSlashReplacement];
    
    return [self.supportPath stringByAppendingPathComponent:filename];
}

- (NSString *)sourcePathForShadowPath:(NSString *)path
{
    NSString *filename = [path stringByReplacingOccurrencesOfString:XCCSlashReplacement withString:@"/"];
    filename = [filename.stringByDeletingPathExtension stringByAppendingPathExtension:@"j"];
    
    return [self.projectPath stringByAppendingPathComponent:filename];
}

#pragma mark - Info plist configurations

- (BOOL)shouldProcessWithObjjWarnings
{
    return !![self settingValueForKey:XCCCappuccinoProcessObjj];
}

- (BOOL)shouldProcessWithCappLint
{
    return !![self settingValueForKey:XCCCappuccinoProcessCappLint];
}

- (BOOL)shouldProcessWithObjj2ObjcSkeleton
{
    return !![self settingValueForKey:XCCCappuccinoProcessObjj2ObjcSkeleton];
}

- (BOOL)shouldProcessWithNib2Cib
{
    return !![self settingValueForKey:XCCCappuccinoProcessNib2Cib];
}

@end
