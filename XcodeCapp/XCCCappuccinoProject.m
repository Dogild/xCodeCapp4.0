//
//  CappuccinoProject.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#include <fcntl.h>

#import "XCCCappuccinoProject.h"
#import "CappuccinoUtils.h"
#import "XCCPath.h"

static NSArray * XCCDefaultEnvironmentPaths;
static NSDictionary* XCCDefaultInfoPlistConfigurations;

// we replace the "/" by a weird unicode "/" in order to generate file names with "/" in .XcodeSupport. very clear huh?
static NSString * const XCCSlashReplacement               = @"∕";  // DIVISION SLASH, Unicode: U+2215
static NSString * const XCCSupportFolderName              = @".XcodeSupport";


NSString * const XCCCappuccinoProcessCappLintKey          = @"XCCCappuccinoProcessCappLintKey";
NSString * const XCCCappuccinoProcessObjjKey              = @"XCCCappuccinoProcessObjjKey";
NSString * const XCCCappuccinoProcessNib2CibKey           = @"XCCCappuccinoProcessNib2CibKey";
NSString * const XCCCappuccinoProcessObjj2ObjcSkeletonKey = @"XCCCappuccinoProcessObjj2ObjcSkeletonKey";
NSString * const XCCCompatibilityVersionKey               = @"XCCCompatibilityVersion";
NSString * const XCCCappuccinoProjectBinPathsKey          = @"XCCCappuccinoProjectBinPathsKey";
NSString * const XCCCappuccinoObjjIncludePathKey          = @"XCCCappuccinoObjjIncludePathKey";
NSString * const XCCCappuccinoProjectNicknameKey          = @"XCCCappuccinoProjectNicknameKey";
NSString * const XCCCappuccinoProjectWasListeningKey      = @"XCCCappuccinoProjectWasListeningKey";

NSString * const XCCProjectDidFinishLoadingNotification   = @"XCCProjectDidFinishLoadingNotification";
NSString * const XCCProjectDidStartLoadingNotification    = @"XCCProjectDidStartLoadingNotification";

@interface XCCCappuccinoProject ()
@property NSFileManager *fm;
@end


@implementation XCCCappuccinoProject

#pragma mark - Class methods

+ (void)initialize
{
    if (self != [XCCCappuccinoProject class])
        return;
    
    XCCDefaultEnvironmentPaths = [NSArray arrayWithObjects:[[XCCPath alloc] initWithName:@"/Users/Tonio/Documents/Alcatel/Applications/CNA-Dashboard/.cappenvs/environments/master/narwhal/bin"], nil];
    
    NSNumber *appCompatibilityVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey];
    
    XCCDefaultInfoPlistConfigurations = @{XCCCompatibilityVersionKey: appCompatibilityVersion,
                                          XCCCappuccinoProcessCappLintKey: @YES,
                                          XCCCappuccinoProcessObjjKey: @YES,
                                          XCCCappuccinoProcessNib2CibKey: @YES,
                                          XCCCappuccinoProcessObjj2ObjcSkeletonKey: @YES,
                                          XCCCappuccinoProjectBinPathsKey: [XCCDefaultEnvironmentPaths valueForKeyPath:@"name"],
                                          XCCCappuccinoObjjIncludePathKey: @"",
                                          XCCCappuccinoProjectNicknameKey: @"",
                                          XCCCappuccinoProjectWasListeningKey: @NO};
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
        self.XcodeCappIgnorePath = [self.projectPath stringByAppendingPathComponent:@".xcodecapp-ignore"];
        self.name = [self.projectPath lastPathComponent];
        self.pbxModifierScriptPath = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"pbxprojModifier.py"];
        
        NSString *projectName = [self.projectPath.lastPathComponent stringByAppendingString:@".xcodeproj"];
        
        self.XcodeProjectPath = [self.projectPath stringByAppendingPathComponent:projectName];
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
    self.errors                     = [NSMutableDictionary new];
    self.status                     = XCCCappuccinoProjectStatusInitialized;
}

- (void)updateIgnoredPath
{
    self.ignoredPathPredicates = [NSMutableArray new];
    
    if ([self.fm fileExistsAtPath:self.XcodeCappIgnorePath])
    {
        @try
        {
            self.ignoredPathsContent = [NSString stringWithContentsOfFile:self.XcodeCappIgnorePath encoding:NSUTF8StringEncoding error:nil];
            
            NSMutableArray *ignoredPatterns = [NSMutableArray new];
            
            for (NSString *pattern in [CappuccinoUtils defaultIgnoredPaths])
                [ignoredPatterns addObject:[NSString stringWithFormat:@"%@/%@", self.projectPath, pattern]];
            
            for (NSString *pattern in [self.ignoredPathsContent componentsSeparatedByString:@"\n"])
                [ignoredPatterns addObject:[NSString stringWithFormat:@"%@/%@", self.projectPath, pattern]];
            
            NSArray *parsedPaths = [CappuccinoUtils parseIgnorePaths:ignoredPatterns];
            [self.ignoredPathPredicates addObjectsFromArray:parsedPaths];
        }
        @catch(NSException *exception)
        {
            DDLogVerbose(@"Content of xcodecapp-ignorepath does not math the expected input");
            self.ignoredPathPredicates = [NSMutableArray array];
        }

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
    self.settings = [NSDictionary dictionaryWithContentsOfFile:self.infoPlistPath];
    
    if (!self.settings)
        self.settings = [self _defaultSettings];
    
    NSMutableArray *mutablePaths = [NSMutableArray array];
    NSArray *paths = [self valueForSetting:XCCCappuccinoProjectBinPathsKey];
    
    if (paths)
    {
        for (NSString *name in paths)
        {
            XCCPath *path = [XCCPath new];
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

- (id)valueForSetting:(NSString*)aKey
{
    return [self.settings valueForKey:aKey];
}

- (void)setValue:(id)aValue forSetting:(NSString*)aKey
{
    [self.settings setValue:aValue forKey:aKey];
}

- (id)_defaultSettings
{
    NSMutableDictionary *defaultSettings = [XCCDefaultInfoPlistConfigurations mutableCopy];
    
    defaultSettings[XCCCappuccinoObjjIncludePathKey] = [NSString stringWithFormat:@"%@/%@", self.projectPath, @"Frameworks/"];
    defaultSettings[XCCCappuccinoProjectNicknameKey] = [self.name copy];
    
    return defaultSettings;
}

- (void)saveSettings
{
    NSMutableDictionary *currentSettings = [self.settings mutableCopy];
    
    [currentSettings setValue:[self.environementsPaths valueForKeyPath:@"name"] forKey:XCCCappuccinoProjectBinPathsKey];
    
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:currentSettings
                                                              format:NSPropertyListXMLFormat_v1_0
                                                    errorDescription:nil];
    
    [data writeToFile:self.infoPlistPath atomically:YES];

    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([self.ignoredPathsContent length])
    {
        NSAttributedString *attributedString = (NSAttributedString*)self.ignoredPathsContent;
        [[attributedString string] writeToFile:self.XcodeCappIgnorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    else if ([fm fileExistsAtPath:self.XcodeCappIgnorePath])
    {
        [fm removeItemAtPath:self.XcodeCappIgnorePath error:nil];
    }
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
    return [self valueForSetting:XCCCappuccinoObjjIncludePathKey];
}

- (void)setObjjIncludePath:(NSString *)objjIncludePath
{
    [self willChangeValueForKey:@"objjIncludePath"];
    [self.settings setValue:objjIncludePath forKey:XCCCappuccinoObjjIncludePathKey];
    [self didChangeValueForKey:@"objjIncludePath"];
}

- (BOOL)shouldProcessWithObjjWarnings
{
    return [[self valueForSetting:XCCCappuccinoProcessObjjKey] boolValue];
}

- (void)setShouldProcessWithObjjWarnings:(BOOL)shouldProcessWithObjjWarnings
{
    [self willChangeValueForKey:@"shouldProcessWithObjjWarnings"];
    [self.settings setValue:[NSNumber numberWithBool:shouldProcessWithObjjWarnings] forKey:XCCCappuccinoProcessObjjKey];
    [self didChangeValueForKey:@"shouldProcessWithObjjWarnings"];
}

- (BOOL)shouldProcessWithCappLint
{
    return [[self valueForSetting:XCCCappuccinoProcessCappLintKey] boolValue];
}

- (void)setShouldProcessWithCappLint:(BOOL)shouldProcessWithCappLint
{
    [self willChangeValueForKey:@"shouldProcessWithCappLint"];
    [self.settings setValue:[NSNumber numberWithInt:shouldProcessWithCappLint] forKey:XCCCappuccinoProcessCappLintKey];
    [self didChangeValueForKey:@"shouldProcessWithCappLint"];
}

- (BOOL)shouldProcessWithObjj2ObjcSkeleton
{
    return [[self valueForSetting:XCCCappuccinoProcessObjj2ObjcSkeletonKey] boolValue];
}

- (void)setShouldProcessWithObjj2ObjcSkeleton:(BOOL)shouldProcessWithObjj2ObjcSkeleton
{
    [self willChangeValueForKey:@"shouldProcessWithObjj2ObjcSkeleton"];
    [self.settings setValue:[NSNumber numberWithBool:shouldProcessWithObjj2ObjcSkeleton] forKey:XCCCappuccinoProcessObjj2ObjcSkeletonKey];
    [self didChangeValueForKey:@"shouldProcessWithObjj2ObjcSkeleton"];
}

- (BOOL)shouldProcessWithNib2Cib
{
    return [[self valueForSetting:XCCCappuccinoProcessNib2CibKey] boolValue];
}

- (void)setShouldProcessWithNib2Cib:(BOOL)shouldProcessWithNib2Cib
{
    [self willChangeValueForKey:@"shouldProcessWithNib2Cib"];
    [self.settings setValue:[NSNumber numberWithBool:shouldProcessWithNib2Cib] forKey:XCCCappuccinoProcessNib2CibKey];
    [self didChangeValueForKey:@"shouldProcessWithNib2Cib"];
}

- (NSString*)nickname
{
    return [self valueForSetting:XCCCappuccinoProjectNicknameKey];
}

- (void)setNickname:(NSString *)nickname
{
    [self willChangeValueForKey:@"nickname"];
    [self.settings setValue:nickname forKey:XCCCappuccinoProjectNicknameKey];
    [self didChangeValueForKey:@"nickname"];
}

- (void)addOperationError:(XCCOperationError *)operationError
{
    if (![self.errors objectForKey:operationError.fileName])
        [self.errors setValue:[NSMutableArray new] forKey:operationError.fileName];

    [self willChangeValueForKey:@"errors"];
    [[self.errors objectForKey:operationError.fileName] addObject:operationError];
    [self didChangeValueForKey:@"errors"];

}

- (void)removeOperationError:(XCCOperationError *)operationError
{
    [self willChangeValueForKey:@"errors"];
    [[self.errors objectForKey:operationError.fileName] removeObject:operationError];
    [self didChangeValueForKey:@"errors"];
    
    if (![[self.errors objectForKey:operationError.fileName] count])
        [self.errors removeObjectForKey:operationError.fileName];
}

- (void)removeAllOperationErrors
{
    [self willChangeValueForKey:@"errors"];
    [self.errors removeAllObjects];
    [self didChangeValueForKey:@"errors"];
}

- (void)removeOperationErrorsRelatedToSourcePath:(NSString *)aPath errorType:(int)anErrorType
{
    NSMutableArray *errorsToRemove = [NSMutableArray array];
    
    for (XCCOperationError *operationError in [self.errors objectForKey:aPath])
        if ([operationError.fileName isEqualToString:aPath] && (operationError.errorType == anErrorType || anErrorType == XCCDefaultOperationErrorType))
            [errorsToRemove addObject:operationError];
    
    for (XCCOperationError *error in errorsToRemove)
        [self removeOperationError:error];
}

- (NSString *)flattenedXcodeSupportFileNameForPath:(NSString *)aPath
{
    NSString *relativePath = [[aPath stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:[self.projectPath stringByAppendingString:@"/"] withString:@""];
    
    return [relativePath stringByReplacingOccurrencesOfString:@"/" withString:XCCSlashReplacement];
}
@end
