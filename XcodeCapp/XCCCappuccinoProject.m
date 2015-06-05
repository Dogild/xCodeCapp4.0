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

static NSArray * XCCDefaultBinaryPaths;
static NSDictionary* XCCDefaultInfoPlistConfigurations;

// we replace the "/" by a weird unicode "/" in order to generate file names with "/" in .XcodeSupport. very clear huh?
static NSString * const XCCSlashReplacement                 = @"∕";  // DIVISION SLASH, Unicode: U+2215


NSString * const XCCCappuccinoProcessCappLintKey            = @"XCCCappuccinoProcessCappLintKey";
NSString * const XCCCappuccinoProcessObjjKey                = @"XCCCappuccinoProcessObjjKey";
NSString * const XCCCappuccinoProcessNib2CibKey             = @"XCCCappuccinoProcessNib2CibKey";
NSString * const XCCCappuccinoProcessObjj2ObjcSkeletonKey   = @"XCCCappuccinoProcessObjj2ObjcSkeletonKey";
NSString * const XCCCompatibilityVersionKey                 = @"XCCCompatibilityVersion";
NSString * const XCCCappuccinoProjectBinPathsKey            = @"XCCCappuccinoProjectBinPathsKey";
NSString * const XCCCappuccinoObjjIncludePathKey            = @"XCCCappuccinoObjjIncludePathKey";
NSString * const XCCCappuccinoProjectNicknameKey            = @"XCCCappuccinoProjectNicknameKey";
NSString * const XCCCappuccinoProjectAutoStartListeningKey  = @"XCCCappuccinoProjectAutoStartListeningKey";
NSString * const XCCCappuccinoProjectLastEventIDKey         = @"XCCCappuccinoProjectLastEventIDKey";



@implementation XCCCappuccinoProject

@synthesize XcodeCappIgnoreContent  = _XcodeCappIgnoreContent;
@synthesize status                  = _status;


#pragma mark - Class methods

+ (void)initialize
{
    if (self != [XCCCappuccinoProject class])
        return;
    
    XCCDefaultBinaryPaths = [NSArray arrayWithObjects:[[XCCPath alloc] initWithName:@"~/bin"], nil];
    
    NSNumber *appCompatibilityVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey];
    
    XCCDefaultInfoPlistConfigurations = @{XCCCompatibilityVersionKey: appCompatibilityVersion,
                                          XCCCappuccinoProcessCappLintKey: @NO,
                                          XCCCappuccinoProcessObjjKey: @NO,
                                          XCCCappuccinoProcessNib2CibKey: @YES,
                                          XCCCappuccinoProcessObjj2ObjcSkeletonKey: @YES,
                                          XCCCappuccinoProjectBinPathsKey: [XCCDefaultBinaryPaths valueForKeyPath:@"name"],
                                          XCCCappuccinoObjjIncludePathKey: @"",
                                          XCCCappuccinoProjectNicknameKey: @"",
                                          XCCCappuccinoProjectAutoStartListeningKey: @NO};
}

+ (NSArray*)defaultBinaryPaths
{
    return XCCDefaultBinaryPaths;
}

#pragma mark - Init methods

- (id)initWithPath:(NSString*)aPath
{
    if (self = [super init])
    {
        self.name                   = [aPath lastPathComponent];
        self.nickname               = self.name;
        self.PBXModifierScriptPath  = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"pbxprojModifier.py"];
        
        [self updateProjectPath:aPath];
    }
    
    return self;
}

- (void)updateProjectPath:(NSString *)path
{
    self.projectPath            = path;
    self.XcodeProjectPath       = [self.projectPath stringByAppendingPathComponent:[[self.projectPath lastPathComponent] stringByAppendingString:@".xcodeproj"]];
    self.XcodeCappIgnorePath    = [self.projectPath stringByAppendingPathComponent:@".xcodecapp-ignore"];
    self.supportPath            = [self.projectPath stringByAppendingPathComponent:@".XcodeSupport"];
    self.settingsPath           = [self.supportPath stringByAppendingPathComponent:@"Info.plist"];
    
    if (self->settings)
        [self saveSettings];
    else
        [self _loadSettings];
    
    [self reloadXcodeCappIgnoreFile];
    [self reinitialize];
}

- (void)reinitialize
{
    self.projectPathsForSourcePaths = [NSMutableDictionary new];
    self.errors                     = [NSMutableDictionary new];
    self.status                     = XCCCappuccinoProjectStatusInitialized;
}


#pragma mark - Settings Management

- (id)_defaultSettings
{
    NSMutableDictionary *defaultSettings = [XCCDefaultInfoPlistConfigurations mutableCopy];
    
    defaultSettings[XCCCappuccinoObjjIncludePathKey] = [NSString stringWithFormat:@"%@/%@", self.projectPath, @"Frameworks/Debug"];
    defaultSettings[XCCCappuccinoProjectNicknameKey] = self.nickname;
    
    return defaultSettings;
}

- (void)_loadSettings
{
    self->settings = [[NSDictionary dictionaryWithContentsOfFile:self.settingsPath] mutableCopy];
    
    if (!self->settings)
        self->settings = [[self _defaultSettings] mutableCopy];
    
    NSMutableArray *mutablePaths = [NSMutableArray array];
    NSArray        *paths        = self->settings[XCCCappuccinoProjectBinPathsKey];
    
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
        mutablePaths = [[[self class] defaultBinaryPaths] mutableCopy];
    }
    
    self.binaryPaths        = mutablePaths;
    self.nickname                 = self->settings[XCCCappuccinoProjectNicknameKey];
    self.objjIncludePath          = self->settings[XCCCappuccinoObjjIncludePathKey];
    self.version                  = self->settings[XCCCompatibilityVersionKey];
    self.processObjjWarnings      = [self->settings[XCCCappuccinoProcessObjjKey] boolValue];
    self.processCappLint          = [self->settings[XCCCappuccinoProcessCappLintKey] boolValue];
    self.processObjj2ObjcSkeleton = [self->settings[XCCCappuccinoProcessObjj2ObjcSkeletonKey] boolValue];
    self.processNib2Cib           = [self->settings[XCCCappuccinoProcessNib2CibKey] boolValue];
    self.autoStartListening       = [self->settings[XCCCappuccinoProjectAutoStartListeningKey] boolValue];
    
    if (self->settings[XCCCappuccinoProjectLastEventIDKey])
        self.lastEventID = self->settings[XCCCappuccinoProjectLastEventIDKey];
}

- (void)_writeSettings
{
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:self->settings format:NSPropertyListXMLFormat_v1_0 errorDescription:nil];
    
    [data writeToFile:self.settingsPath atomically:YES];
}

- (void)saveSettings
{
    self->settings[XCCCappuccinoProjectBinPathsKey]              = [self.binaryPaths valueForKeyPath:@"name"];
    self->settings[XCCCappuccinoObjjIncludePathKey]              = self.objjIncludePath;
    self->settings[XCCCappuccinoProjectNicknameKey]              = self.nickname;
    self->settings[XCCCompatibilityVersionKey]                   = self.version;
    self->settings[XCCCappuccinoProcessObjjKey]                  = [NSNumber numberWithBool:self.processObjjWarnings];
    self->settings[XCCCappuccinoProcessCappLintKey]              = [NSNumber numberWithBool:self.processCappLint];
    self->settings[XCCCappuccinoProcessObjj2ObjcSkeletonKey]     = [NSNumber numberWithBool:self.processObjj2ObjcSkeleton];
    self->settings[XCCCappuccinoProcessNib2CibKey]               = [NSNumber numberWithBool:self.processNib2Cib];
    self->settings[XCCCappuccinoProjectAutoStartListeningKey]    = [NSNumber numberWithBool:self.autoStartListening];
    
    if ([self.lastEventID boolValue])
        self->settings[XCCCappuccinoProjectLastEventIDKey]           = self.lastEventID;
    
    [self _writeXcodeCappIgnoreFile];
    [self _writeSettings];
}


#pragma mark - XcodeCapp Ignore

- (void)_writeXcodeCappIgnoreFile
{
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:self->settings format:NSPropertyListXMLFormat_v1_0 errorDescription:nil];
    
    [data writeToFile:self.settingsPath atomically:YES];
    
    NSFileManager *fm = [NSFileManager defaultManager];

    if ([self.XcodeCappIgnoreContent length])
        [self.XcodeCappIgnoreContent writeToFile:self.XcodeCappIgnorePath atomically:YES encoding:NSASCIIStringEncoding error:nil];
    else if ([fm fileExistsAtPath:self.XcodeCappIgnorePath])
        [fm removeItemAtPath:self.XcodeCappIgnorePath error:nil];
}

- (void)_updateXcodeCappIgnorePredicates
{
    self.ignoredPathPredicates = [NSMutableArray new];
    
    @try
    {
        NSMutableArray *ignoredPatterns = [NSMutableArray new];
        
        for (NSString *pattern in [CappuccinoUtils defaultIgnoredPaths])
            [ignoredPatterns addObject:pattern];
        
        for (NSString *pattern in [self.XcodeCappIgnoreContent componentsSeparatedByString:@"\n"])
            if ([pattern length])
                [ignoredPatterns addObject:pattern];

        NSArray *parsedPaths = [CappuccinoUtils parseIgnorePaths:ignoredPatterns basePath:self.projectPath];
        [self.ignoredPathPredicates addObjectsFromArray:parsedPaths];
        
        DDLogVerbose(@"Content of xcodecapp-ignorepath correctly updated %@", self.ignoredPathPredicates);
    }
    @catch(NSException *exception)
    {
        DDLogVerbose(@"Content of xcodecapp-ignorepath does not math the expected input");
        self.ignoredPathPredicates = [NSMutableArray array];
    }
}

- (void)reloadXcodeCappIgnoreFile
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:self.XcodeCappIgnorePath])
        self.XcodeCappIgnoreContent = [NSString stringWithContentsOfFile:self.XcodeCappIgnorePath encoding:NSASCIIStringEncoding error:nil];
}


#pragma mark Paths Management

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

- (NSString *)flattenedXcodeSupportFileNameForPath:(NSString *)aPath
{
    NSString *relativePath = [[aPath stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:[self.projectPath stringByAppendingString:@"/"] withString:@""];
    
    return [relativePath stringByReplacingOccurrencesOfString:@"/" withString:XCCSlashReplacement];
}


#pragma marks Operation Management

- (void)addOperationError:(XCCOperationError *)operationError
{
    if (!operationError.fileName)
        operationError.fileName = @"/No Filename";
    
    [self willChangeValueForKey:@"errors"];
    
    if (![self.errors objectForKey:operationError.fileName])
        [self.errors setValue:[NSMutableArray new] forKey:operationError.fileName];
    
    [[self.errors objectForKey:operationError.fileName] addObject:operationError];
    
    [self didChangeValueForKey:@"errors"];
}

- (void)removeOperationError:(XCCOperationError *)operationError
{
    if (!operationError.fileName)
        operationError.fileName = @"/No Filename";

    [self willChangeValueForKey:@"errors"];
    
    [[self.errors objectForKey:operationError.fileName] removeObject:operationError];
    
    if (![[self.errors objectForKey:operationError.fileName] count])
        [self.errors removeObjectForKey:operationError.fileName];
    
    [self didChangeValueForKey:@"errors"];
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


#pragma mark - Custom Getters and Setters

- (XCCCappuccinoProjectStatus)status
{
    return _status;
}

- (void)setStatus:(XCCCappuccinoProjectStatus)status
{
    [self willChangeValueForKey:@"status"];
    _status = status;
    [self didChangeValueForKey:@"status"];
    
    self.isBusy = (_status == XCCCappuccinoProjectStatusLoading || _status == XCCCappuccinoProjectStatusProcessing);
}

- (NSString *)XcodeCappIgnoreContent
{
    return _XcodeCappIgnoreContent;
}

- (void)setXcodeCappIgnoreContent:(NSString *)XcodeCappIgnoreContent
{
    if ([XcodeCappIgnoreContent isEqualToString:_XcodeCappIgnoreContent])
        return;

    [self willChangeValueForKey:@"XcodeCappIgnoreContent"];
    _XcodeCappIgnoreContent = XcodeCappIgnoreContent;
    [self _updateXcodeCappIgnorePredicates];
    [self didChangeValueForKey:@"XcodeCappIgnoreContent"];
}

@end
