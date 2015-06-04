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
static NSString * const XCCSlashReplacement                 = @"∕";  // DIVISION SLASH, Unicode: U+2215
static NSString * const XCCSupportFolderName                = @".XcodeSupport";


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

@interface XCCCappuccinoProject ()
@property NSFileManager *fm;
@end


@implementation XCCCappuccinoProject

@synthesize XcodeCappIgnoreContent  = _XcodeCappIgnoreContent;
@synthesize status                  = _status;


#pragma mark - Class methods

+ (void)initialize
{
    if (self != [XCCCappuccinoProject class])
        return;
    
    XCCDefaultEnvironmentPaths = [NSArray arrayWithObjects:[[XCCPath alloc] initWithName:@"~/bin"], nil];
    
    NSNumber *appCompatibilityVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey];
    
    XCCDefaultInfoPlistConfigurations = @{XCCCompatibilityVersionKey: appCompatibilityVersion,
                                          XCCCappuccinoProcessCappLintKey: @YES,
                                          XCCCappuccinoProcessObjjKey: @YES,
                                          XCCCappuccinoProcessNib2CibKey: @YES,
                                          XCCCappuccinoProcessObjj2ObjcSkeletonKey: @YES,
                                          XCCCappuccinoProjectBinPathsKey: [XCCDefaultEnvironmentPaths valueForKeyPath:@"name"],
                                          XCCCappuccinoObjjIncludePathKey: @"",
                                          XCCCappuccinoProjectNicknameKey: @"",
                                          XCCCappuccinoProjectAutoStartListeningKey: @NO,
                                          XCCCappuccinoProjectLastEventIDKey: [NSNumber numberWithLongLong:kFSEventStreamEventIdSinceNow]};
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
        self.PBXModifierScriptPath = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"pbxprojModifier.py"];
        
        NSString *projectName = [self.projectPath.lastPathComponent stringByAppendingString:@".xcodeproj"];
        
        self.XcodeProjectPath = [self.projectPath stringByAppendingPathComponent:projectName];
        self.supportPath = [self.projectPath stringByAppendingPathComponent:XCCSupportFolderName];
        self.infoPlistPath = [self.supportPath stringByAppendingPathComponent:@"Info.plist"];
        
        [self _loadSettings];
        [self reloadXcodeCappIgnoreFile];
        
        [self reinitialize];
    }
    
    return self;
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
    
    defaultSettings[XCCCappuccinoObjjIncludePathKey] = [NSString stringWithFormat:@"%@/%@", self.projectPath, @"Frameworks/"];
    defaultSettings[XCCCappuccinoProjectNicknameKey] = [self.name copy];
    
    return defaultSettings;
}

- (void)_loadSettings
{
    self->settings = [[NSDictionary dictionaryWithContentsOfFile:self.infoPlistPath] mutableCopy];
    
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
        mutablePaths = [[[self class] defaultEnvironmentPaths] mutableCopy];
    }
    
    self.environmentsPaths        = mutablePaths;
    self.nickname                 = self->settings[XCCCappuccinoProjectNicknameKey];
    self.objjIncludePath          = self->settings[XCCCappuccinoObjjIncludePathKey];
    self.version                  = self->settings[XCCCompatibilityVersionKey];
    self.processObjjWarnings      = [self->settings[XCCCappuccinoProcessObjjKey] boolValue];
    self.processCappLint          = [self->settings[XCCCappuccinoProcessCappLintKey] boolValue];
    self.processObjj2ObjcSkeleton = [self->settings[XCCCappuccinoProcessObjj2ObjcSkeletonKey] boolValue];
    self.processNib2Cib           = [self->settings[XCCCappuccinoProcessNib2CibKey] boolValue];
    self.autoStartListening       = [self->settings[XCCCappuccinoProjectAutoStartListeningKey] boolValue];
    self.lastEventID              = [NSNumber numberWithLongLong:[self->settings[XCCCappuccinoProjectLastEventIDKey] longLongValue]];
}

- (void)_writeSettings
{
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:self->settings format:NSPropertyListXMLFormat_v1_0 errorDescription:nil];
    
    [data writeToFile:self.infoPlistPath atomically:YES];
}

- (void)saveSettings
{
    self->settings[XCCCappuccinoProjectBinPathsKey]              = [self.environmentsPaths valueForKeyPath:@"name"];
    self->settings[XCCCappuccinoObjjIncludePathKey]              = self.objjIncludePath;
    self->settings[XCCCappuccinoProjectNicknameKey]              = self.nickname;
    self->settings[XCCCompatibilityVersionKey]                   = self.version;
    self->settings[XCCCappuccinoProcessObjjKey]                  = [NSNumber numberWithBool:self.processObjjWarnings];
    self->settings[XCCCappuccinoProcessCappLintKey]              = [NSNumber numberWithBool:self.processCappLint];
    self->settings[XCCCappuccinoProcessObjj2ObjcSkeletonKey]     = [NSNumber numberWithBool:self.processObjj2ObjcSkeleton];
    self->settings[XCCCappuccinoProcessNib2CibKey]               = [NSNumber numberWithBool:self.processNib2Cib];
    self->settings[XCCCappuccinoProjectAutoStartListeningKey]    = [NSNumber numberWithBool:self.autoStartListening];
    self->settings[XCCCappuccinoProjectLastEventIDKey]           = self.lastEventID;
    
    [self _writeXcodeCappIgnoreFile];
    [self _writeSettings];
}


#pragma mark - XcodeCapp Ignore

- (void)_writeXcodeCappIgnoreFile
{
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:self->settings format:NSPropertyListXMLFormat_v1_0 errorDescription:nil];
    
    [data writeToFile:self.infoPlistPath atomically:YES];
    
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
            [ignoredPatterns addObject:[NSString stringWithFormat:@"%@/%@", self.projectPath, pattern]];
        
        for (NSString *pattern in [self.XcodeCappIgnoreContent componentsSeparatedByString:@"\n"])
            if ([pattern length])
                [ignoredPatterns addObject:[NSString stringWithFormat:@"%@/%@", self.projectPath, pattern]];
        
        NSArray *parsedPaths = [CappuccinoUtils parseIgnorePaths:ignoredPatterns];
        [self.ignoredPathPredicates addObjectsFromArray:parsedPaths];
        
        DDLogVerbose(@"Content of xcodecapp-ignorepath correctly updated %@", self.ignoredPathPredicates);
    }
    @catch(NSException *exception)
    {
        DDLogVerbose(@"Content of xcodecapp-ignorepath does not math the expected input");
        self.ignoredPathPredicates = [NSMutableArray array];
    }
    
    [self _writeXcodeCappIgnoreFile];

}

- (void)reloadXcodeCappIgnoreFile
{
    self.ignoredPathPredicates = [NSMutableArray new];
    
    if ([self.fm fileExistsAtPath:self.XcodeCappIgnorePath])
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
    [self willChangeValueForKey:@"errors"];
    
    if (![self.errors objectForKey:operationError.fileName])
        [self.errors setValue:[NSMutableArray new] forKey:operationError.fileName];

    [[self.errors objectForKey:operationError.fileName] addObject:operationError];
    
    [self didChangeValueForKey:@"errors"];
}

- (void)removeOperationError:(XCCOperationError *)operationError
{
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
    [self willChangeValueForKey:@"XcodeCappIgnoreContent"];
    _XcodeCappIgnoreContent = XcodeCappIgnoreContent;
    [self didChangeValueForKey:@"XcodeCappIgnoreContent"];
    
    [self _updateXcodeCappIgnorePredicates];
}

@end
