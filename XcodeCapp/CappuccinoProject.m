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
#import "Path.h"

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

// Path used by objj
NSString *const XCCCappuccinoObjjIncludePath = @"XCCCappuccinoObjjIncludePath";

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
    
    XCCDefaultEnvironmentPaths = [NSArray arrayWithObjects:[[Path alloc] initWithName:@"/usr/local/narwhal/bin"], [[Path alloc] initWithName:@"~/narwhal/bin"], nil];
    
    NSNumber *appCompatibilityVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey];
    
    XCCDefaultInfoPlistConfigurations = @{XCCCompatibilityVersionKey: appCompatibilityVersion,
                                          XCCCappuccinoProcessCappLint: @YES,
                                          XCCCappuccinoProcessObjj: @YES,
                                          XCCCappuccinoProcessNib2Cib: @YES,
                                          XCCCappuccinoProcessObjj2ObjcSkeleton: @YES,
                                          XCCCappuccinoProjectBinPaths: [XCCDefaultEnvironmentPaths valueForKeyPath:@"name"],
                                          XCCCappuccinoObjjIncludePath: @""};
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
        self.projectName = [self.projectPath lastPathComponent];
        self.pbxModifierScriptPath = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"pbxprojModifier.py"];
        
        NSString *projectName = [self.projectPath.lastPathComponent stringByAppendingString:@".xcodeproj"];
        
        self.xcodeProjectPath = [self.projectPath stringByAppendingPathComponent:projectName];
        self.supportPath = [self.projectPath stringByAppendingPathComponent:XCCSupportFolderName];
        self.infoPlistPath = [self.supportPath stringByAppendingPathComponent:@"Info.plist"];
        
        [self fetchProjectSettings];
        [self updateIgnoredPath];
        
        [self _init];
    }
    
    return self;
}

- (void)_init
{
    self.projectPathsForSourcePaths = [NSMutableDictionary new];
    self.errors = [NSMutableDictionary new];
    
    self.isLoadingProject = NO;
    self.isListeningProject = NO;
    self.isProcessingProject = NO;
    self.isProjectLoaded = NO;
}

- (void)updateIgnoredPath
{
    self.ignoredPathPredicates = [NSMutableArray new];
    
    if ([self.fm fileExistsAtPath:self.xcodecappIgnorePath])
    {
        self.ignoredPathsContent = [NSString stringWithContentsOfFile:self.xcodecappIgnorePath encoding:NSUTF8StringEncoding error:nil];
        NSArray *ignoredPatterns = [self.ignoredPathsContent componentsSeparatedByString:@"\n"];
        NSArray *parsedPaths = [CappuccinoUtils parseIgnorePaths:ignoredPatterns];
        [self.ignoredPathPredicates addObjectsFromArray:parsedPaths];
    }
    
    DDLogVerbose(@"Ignoring file paths: %@", self.ignoredPathPredicates);
}

- (void)fetchProjectSettings
{
    [self willChangeValueForKey:@"objjIncludePath"];
    [self willChangeValueForKey:@"shouldProcessWithObjjWarnings"];
    [self willChangeValueForKey:@"shouldProcessWithCappLint"];
    [self willChangeValueForKey:@"shouldProcessWithObjj2ObjcSkeleton"];
    [self willChangeValueForKey:@"shouldProcessWithNib2Cib"];
    [self willChangeValueForKey:@"environementsPaths"];
    self.projectSettings = [NSDictionary dictionaryWithContentsOfFile:self.infoPlistPath];
    
    NSMutableArray *mutablePaths = [NSMutableArray array];
    NSArray *paths = [self settingValueForKey:XCCCappuccinoProjectBinPaths];
    
    if (paths)
    {
        for (NSString *name in paths)
        {
            Path *path = [Path new];
            [path setName:name];
            [mutablePaths addObject:path];
        }
    }
    else
    {
        mutablePaths = [[[self class] defaultEnvironmentPaths] mutableCopy];
    }
    
    self.environementsPaths = mutablePaths;
    
    [self didChangeValueForKey:@"objjIncludePath"];
    [self didChangeValueForKey:@"shouldProcessWithObjjWarnings"];
    [self didChangeValueForKey:@"shouldProcessWithCappLint"];
    [self didChangeValueForKey:@"shouldProcessWithObjj2ObjcSkeleton"];
    [self didChangeValueForKey:@"shouldProcessWithNib2Cib"];
    [self didChangeValueForKey:@"environementsPaths"];
}

- (id)settingValueForKey:(NSString*)aKey
{
    return [self.projectSettings valueForKey:aKey];
}

- (void)updateSettingValue:(id)aValue forKey:(NSString*)aKey
{
    [self.projectSettings setValue:aValue forKey:aKey];
}

- (id)defaultSettings
{
    NSMutableDictionary *defaultSettings = [XCCDefaultInfoPlistConfigurations mutableCopy];
    
    defaultSettings[XCCCappuccinoObjjIncludePath] = [NSString stringWithFormat:@"%@/%@", self.projectPath, @"Frameworks/"];
    
    return defaultSettings;
}

- (NSMutableDictionary*)currentSettings
{
    [self.projectSettings setValue:[self.environementsPaths valueForKeyPath:@"name"] forKey:XCCCappuccinoProjectBinPaths];
    
    return [self.projectSettings mutableCopy];
}

#pragma mark path methods

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


#pragma marks Setting accessors

- (NSString *)objjIncludePath
{
    return [self settingValueForKey:XCCCappuccinoObjjIncludePath];
}

- (void)setObjjIncludePath:(NSString *)objjIncludePath
{
    [self willChangeValueForKey:@"objjIncludePath"];
    [self.projectSettings setValue:objjIncludePath forKey:XCCCappuccinoObjjIncludePath];
    [self didChangeValueForKey:@"objjIncludePath"];
}

- (BOOL)shouldProcessWithObjjWarnings
{
    return [[self settingValueForKey:XCCCappuccinoProcessObjj] boolValue];
}

- (void)setShouldProcessWithObjjWarnings:(BOOL)shouldProcessWithObjjWarnings
{
    [self willChangeValueForKey:@"shouldProcessWithObjjWarnings"];
    [self.projectSettings setValue:[NSNumber numberWithBool:shouldProcessWithObjjWarnings] forKey:XCCCappuccinoProcessObjj];
    [self didChangeValueForKey:@"shouldProcessWithObjjWarnings"];
}

- (BOOL)shouldProcessWithCappLint
{
    return [[self settingValueForKey:XCCCappuccinoProcessCappLint] boolValue];
}

- (void)setShouldProcessWithCappLint:(BOOL)shouldProcessWithCappLint
{
    [self willChangeValueForKey:@"shouldProcessWithCappLint"];
    [self.projectSettings setValue:[NSNumber numberWithInt:shouldProcessWithCappLint] forKey:XCCCappuccinoProcessCappLint];
    [self didChangeValueForKey:@"shouldProcessWithCappLint"];
}

- (BOOL)shouldProcessWithObjj2ObjcSkeleton
{
    return [[self settingValueForKey:XCCCappuccinoProcessObjj2ObjcSkeleton] boolValue];
}

- (void)setShouldProcessWithObjj2ObjcSkeleton:(BOOL)shouldProcessWithObjj2ObjcSkeleton
{
    [self willChangeValueForKey:@"shouldProcessWithObjj2ObjcSkeleton"];
    [self.projectSettings setValue:[NSNumber numberWithBool:shouldProcessWithObjj2ObjcSkeleton] forKey:XCCCappuccinoProcessObjj2ObjcSkeleton];
    [self didChangeValueForKey:@"shouldProcessWithObjj2ObjcSkeleton"];
}

- (BOOL)shouldProcessWithNib2Cib
{
    return [[self settingValueForKey:XCCCappuccinoProcessNib2Cib] boolValue];
}

- (void)setShouldProcessWithNib2Cib:(BOOL)shouldProcessWithNib2Cib
{
    [self willChangeValueForKey:@"shouldProcessWithNib2Cib"];
    [self.projectSettings setValue:[NSNumber numberWithBool:shouldProcessWithNib2Cib] forKey:XCCCappuccinoProcessNib2Cib];
    [self didChangeValueForKey:@"shouldProcessWithNib2Cib"];
}

@end
