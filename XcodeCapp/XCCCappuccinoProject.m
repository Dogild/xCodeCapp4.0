//
//  CappuccinoProject.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#include <fcntl.h>

#import "XCCCappuccinoProject.h"
#import "XCCPath.h"

static NSArray * XCCDefaultBinaryPaths;
static NSDictionary* XCCCappuccinoProjectDefaultSettings;

// we replace the "/" by a weird unicode "/" in order to generate file names with "/" in .XcodeSupport. very clear huh?
static NSString * const XCCSlashReplacement                 = @"∕";  // DIVISION SLASH, Unicode: U+2215

static NSPredicate * XCCDirectoriesToIgnorePredicate = nil;
static NSString * const XCCDirectoriesToIgnorePattern = @"^(?:Build|F(?:rameworks|oundation)|AppKit|Objective-J|(?:Browser|CommonJS)\\.environment|Resources|XcodeSupport|.+\\.xcodeproj)$";

static NSArray *XCCCappuccinoProjectDefaultIgnoredPaths = nil;

NSString * const XCCCappuccinoProcessCappLintKey            = @"XCCCappuccinoProcessCappLintKey";
NSString * const XCCCappuccinoProcessObjjKey                = @"XCCCappuccinoProcessObjjKey";
NSString * const XCCCappuccinoProcessNib2CibKey             = @"XCCCappuccinoProcessNib2CibKey";
NSString * const XCCCappuccinoProcessObjj2ObjcSkeletonKey   = @"XCCCappuccinoProcessObjj2ObjcSkeletonKey";
NSString * const XCCCompatibilityVersionKey                 = @"XCCCompatibilityVersion";
NSString * const XCCCappuccinoProjectBinPathsKey            = @"XCCCappuccinoProjectBinPathsKey";
NSString * const XCCCappuccinoObjjIncludePathKey            = @"XCCCappuccinoObjjIncludePathKey";
NSString * const XCCCappuccinoProjectNicknameKey            = @"XCCCappuccinoProjectNicknameKey";
NSString * const XCCCappuccinoProjectPreviousStatusKey      = @"XCCCappuccinoProjectPreviousStatusKey";
NSString * const XCCCappuccinoProjectLastEventIDKey         = @"XCCCappuccinoProjectLastEventIDKey";




@implementation XCCCappuccinoProject

@synthesize XcodeCappIgnoreContent  = _XcodeCappIgnoreContent;
@synthesize status                  = _status;
@synthesize numberOfErrors          = _numberOfErrors;

#pragma mark - Class methods

+ (void)initialize
{
    if (self != [XCCCappuccinoProject class])
        return;
    
    XCCDefaultBinaryPaths = @[[[XCCPath alloc] initWithName:@"~/bin"]];
    
    NSNumber *appCompatibilityVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey];

    XCCDirectoriesToIgnorePredicate = [NSPredicate predicateWithFormat:@"SELF matches %@", XCCDirectoriesToIgnorePattern];

    XCCCappuccinoProjectDefaultSettings = @{XCCCompatibilityVersionKey: appCompatibilityVersion,
                                          XCCCappuccinoProcessCappLintKey: @NO,
                                          XCCCappuccinoProcessObjjKey: @NO,
                                          XCCCappuccinoProcessNib2CibKey: @YES,
                                          XCCCappuccinoProcessObjj2ObjcSkeletonKey: @YES,
                                          XCCCappuccinoProjectBinPathsKey: [XCCDefaultBinaryPaths valueForKeyPath:@"name"],
                                          XCCCappuccinoObjjIncludePathKey: @"",
                                          XCCCappuccinoProjectNicknameKey: @"",
                                          XCCCappuccinoProjectPreviousStatusKey: @0};

    XCCCappuccinoProjectDefaultIgnoredPaths = @[
                                                @"Frameworks/*",
                                                @"Build/*",
                                                @"*.xcodeproj/*",
                                                @".XcodeSupport/*",
                                                @"NS_*.j",
                                                @".xcodecapp-ignore",
                                                @"*.git/*",
                                                @".cappenvs/*",
                                                @"main.j",
                                                @"!Frameworks/Sources"
                                                ];
}

+ (NSArray*)defaultBinaryPaths
{
    return XCCDefaultBinaryPaths;
}

+ (BOOL)isObjjFile:(NSString *)path
{
    return [path.pathExtension.lowercaseString isEqual:@"j"];
}

+ (BOOL)isCibFile:(NSString *)path
{
    return [path.pathExtension.lowercaseString isEqual:@"cib"];
}

+ (BOOL)isHeaderFile:(NSString *)path
{
    return [path.pathExtension.lowercaseString isEqual:@"h"];
}

+ (BOOL)isXibFile:(NSString *)path
{
    NSString *extension = path.pathExtension.lowercaseString;

    if ([extension isEqual:@"xib"] || [extension isEqual:@"nib"])
    {
        // Xcode creates temp files called <filename>~.xib. Filter those out.
        NSString *baseFilename = path.lastPathComponent.stringByDeletingPathExtension;

        return [baseFilename characterAtIndex:baseFilename.length - 1] != '~';
    }

    return NO;
}

+ (BOOL)isXCCIgnoreFile:(NSString *)path cappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject
{
    return [path isEqualToString:aCappuccinoProject.XcodeCappIgnorePath];
}

+ (BOOL)isSourceFile:(NSString *)path cappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject
{
    return ([self isXibFile:path] || [self isObjjFile:path]) && ![self pathMatchesIgnoredPaths:path cappuccinoProjectIgnoredPathPredicates:aCappuccinoProject.ignoredPathPredicates];
}

+ (BOOL)shouldIgnoreDirectoryNamed:(NSString *)filename
{
    return [XCCDirectoriesToIgnorePredicate evaluateWithObject:filename];
}

+ (BOOL)pathMatchesIgnoredPaths:(NSString*)aPath cappuccinoProjectIgnoredPathPredicates:(NSMutableArray*)cappuccinoProjectIgnoredPathPredicates
{
    BOOL ignore = NO;

    for (NSDictionary *ignoreInfo in cappuccinoProjectIgnoredPathPredicates)
    {
        BOOL matches = [ignoreInfo[@"predicate"] evaluateWithObject:aPath];

        if (matches)
            ignore = [ignoreInfo[@"exclude"] boolValue];
    }

    return ignore;
}

+ (NSArray *)parseIgnorePaths:(NSArray *)paths basePath:(NSString *)basePath
{
    NSMutableArray *parsedPaths = [@[] mutableCopy];
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];

    for (NSString *pattern in paths)
    {
        if ([pattern stringByTrimmingCharactersInSet:whitespace].length == 0)
            continue;

        BOOL        exclude       = [pattern characterAtIndex:0] != '!';
        NSString    *finalPattern = exclude ? pattern : [pattern substringFromIndex:1];

        NSString *regexPattern = [self globToRegexPattern:[NSString stringWithFormat:@"%@/%@", basePath, finalPattern]];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF matches %@", regexPattern];
        [parsedPaths addObject:@{ @"predicate": predicate,
                                  @"exclude": @(exclude)}];
    }

    return parsedPaths;
}

+ (NSString *)globToRegexPattern:(NSString *)glob
{
    NSMutableString *regex = [glob mutableCopy];

    if ([regex characterAtIndex:0] == '!')
        [regex deleteCharactersInRange:NSMakeRange(0, 1)];

    [regex replaceOccurrencesOfString:@"."
                           withString:@"\\."
                              options:0
                                range:NSMakeRange(0, [regex length])];

    [regex replaceOccurrencesOfString:@"*"
                           withString:@".*"
                              options:0
                                range:NSMakeRange(0, [regex length])];

    // If the glob ends with "/", match that directory and anything below it.
    if ([regex characterAtIndex:regex.length - 1] == '/')
        [regex replaceCharactersInRange:NSMakeRange(regex.length - 1, 1) withString:@"(?:/.*)?"];

    return [NSString stringWithFormat:@"^%@$", regex];
}

+ (NSArray *)getPathsToWatchForCappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject
{
    NSMutableArray  *pathsToWatch       = [@[aCappuccinoProject.projectPath] mutableCopy];
    NSArray         *otherPathsToWatch  = @[@"", @"Frameworks/Debug", @"Frameworks/Source"];
    NSFileManager   *fm                 = [NSFileManager defaultManager];

    for (NSString *path in otherPathsToWatch)
    {
        NSString *fullPath = [aCappuccinoProject.projectPath stringByAppendingPathComponent:path];

        BOOL exists, isDirectory;
        exists = [fm fileExistsAtPath:fullPath isDirectory:&isDirectory];

        if (exists && isDirectory)
            [self watchSymlinkedDirectoriesAtPath:path pathsToWatch:pathsToWatch cappuccinoProject:aCappuccinoProject];
    }

    return [pathsToWatch copy];
}

+ (void)watchSymlinkedDirectoriesAtPath:(NSString *)projectPath pathsToWatch:(NSMutableArray *)pathsToWatch cappuccinoProject:(XCCCappuccinoProject*)aCappuccinoProject
{
    NSString *fullProjectPath = [aCappuccinoProject.projectPath stringByAppendingPathComponent:projectPath];
    NSError *error = NULL;
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *urls = [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:fullProjectPath]
                      includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey]
                                         options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                           error:&error];

    for (NSURL *url in urls)
    {
        NSNumber *isSymlink;
        [url getResourceValue:&isSymlink forKey:NSURLIsSymbolicLinkKey error:nil];

        if (isSymlink.boolValue == NO)
            continue;

        NSURL *resolvedURL = [url URLByResolvingSymlinksInPath];

        if (![resolvedURL checkResourceIsReachableAndReturnError:nil])
            continue;

        NSNumber *isDirectory;
        [resolvedURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if (isDirectory.boolValue == NO)
            continue;

        NSString *path = resolvedURL.path;
        NSString *filename = path.lastPathComponent;

        if (![self shouldIgnoreDirectoryNamed:filename] && ![self pathMatchesIgnoredPaths:path cappuccinoProjectIgnoredPathPredicates:aCappuccinoProject.ignoredPathPredicates])
        {
            DDLogVerbose(@"Watching symlinked directory: %@", path);

            [pathsToWatch addObject:path];
        }
    }
}

+ (void)notifyUserWithTitle:(NSString *)aTitle message:(NSString *)aMessage
{
    NSUserNotification *note = [NSUserNotification new];

    note.title = aTitle;
    note.informativeText = aMessage;

    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
}


#pragma mark - Init methods

- (instancetype)initWithPath:(NSString*)aPath
{
    if (self = [super init])
    {
        self.name                   = [aPath lastPathComponent];
        self.nickname               = self.name;
        self.projectPath            = aPath;
        self.numberOfErrors         = 0;
        self.PBXModifierScriptPath  = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"pbxprojModifier.py"];
        self.XcodeProjectPath       = [self.projectPath stringByAppendingPathComponent:[[self.projectPath lastPathComponent] stringByAppendingString:@".xcodeproj"]];
        self.XcodeCappIgnorePath    = [self.projectPath stringByAppendingPathComponent:@".xcodecapp-ignore"];
        self.supportPath            = [self.projectPath stringByAppendingPathComponent:@".XcodeSupport"];
        self.settingsPath           = [self.supportPath stringByAppendingPathComponent:@"Info.plist"];

        [self _loadSettings];

        [self reloadXcodeCappIgnoreFile];

        [self reinitialize];
    }
    
    return self;
}

- (void)reinitialize
{
    self.projectPathsForSourcePaths = [@{} mutableCopy];
    self.errors                     = [@{} mutableCopy];
    self.status                     = XCCCappuccinoProjectStatusStopped;
}


#pragma mark - Settings Management

- (id)_defaultSettings
{
    NSMutableDictionary *defaultSettings = [XCCCappuccinoProjectDefaultSettings mutableCopy];
    
    defaultSettings[XCCCappuccinoObjjIncludePathKey] = [NSString stringWithFormat:@"%@/%@", self.projectPath, @"Frameworks/Debug"];
    defaultSettings[XCCCappuccinoProjectNicknameKey] = self.nickname;
    
    return defaultSettings;
}

- (void)_loadSettings
{
    self->settings = [[NSDictionary dictionaryWithContentsOfFile:self.settingsPath] mutableCopy];
    
    if (!self->settings)
        self->settings = [[self _defaultSettings] mutableCopy];
    
    NSMutableArray *mutablePaths = [@[] mutableCopy];
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
    self.previousSavedStatus      = [self->settings[XCCCappuccinoProjectPreviousStatusKey] intValue];

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
    self->settings[XCCCappuccinoProcessObjjKey]                  = @(self.processObjjWarnings);
    self->settings[XCCCappuccinoProcessCappLintKey]              = @(self.processCappLint);
    self->settings[XCCCappuccinoProcessObjj2ObjcSkeletonKey]     = @(self.processObjj2ObjcSkeleton);
    self->settings[XCCCappuccinoProcessNib2CibKey]               = @(self.processNib2Cib);
    self->settings[XCCCappuccinoProjectPreviousStatusKey]        = [NSNumber numberWithInt:self.status];
    
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
    self.ignoredPathPredicates = [@[] mutableCopy];
    
    @try
    {
        NSMutableArray *ignoredPatterns = [@[] mutableCopy];
        
        for (NSString *pattern in XCCCappuccinoProjectDefaultIgnoredPaths)
            [ignoredPatterns addObject:pattern];
        
        for (NSString *pattern in [self.XcodeCappIgnoreContent componentsSeparatedByString:@"\n"])
            if ([pattern length])
                [ignoredPatterns addObject:pattern];

        NSArray *parsedPaths = [XCCCappuccinoProject parseIgnorePaths:ignoredPatterns basePath:self.projectPath];
        [self.ignoredPathPredicates addObjectsFromArray:parsedPaths];
        
        DDLogVerbose(@"Content of xcodecapp-ignorepath correctly updated %@", self.ignoredPathPredicates);
    }
    @catch(NSException *exception)
    {
        DDLogVerbose(@"Content of xcodecapp-ignorepath does not math the expected input");
        self.ignoredPathPredicates = [@[] mutableCopy];
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
    
    if (!self.errors[operationError.fileName])
        self.errors[operationError.fileName] = [@[] mutableCopy];
    
    [self.errors[operationError.fileName] addObject:operationError];
    
    [self didChangeValueForKey:@"errors"];
    self.numberOfErrors++;
}

- (void)removeOperationError:(XCCOperationError *)operationError
{
    if (!operationError.fileName)
        operationError.fileName = @"/No Filename";

    [self willChangeValueForKey:@"errors"];
    
    [self.errors[operationError.fileName] removeObject:operationError];
    
    if (![self.errors[operationError.fileName] count])
        [self.errors removeObjectForKey:operationError.fileName];
    
    [self didChangeValueForKey:@"errors"];
    self.numberOfErrors--;
}

- (void)removeAllOperationErrors
{
    [self willChangeValueForKey:@"errors"];
    [self.errors removeAllObjects];
    [self didChangeValueForKey:@"errors"];
    self.numberOfErrors = 0;
}

- (void)removeOperationErrorsRelatedToSourcePath:(NSString *)aPath errorType:(int)anErrorType
{
    NSMutableArray *errorsToRemove = [@[] mutableCopy];
    
    for (XCCOperationError *operationError in self.errors[aPath])
        if ([operationError.fileName isEqualToString:aPath] && (operationError.errorType == anErrorType || anErrorType == XCCDefaultOperationErrorType))
            [errorsToRemove addObject:operationError];
    
    for (XCCOperationError *error in errorsToRemove)
        [self removeOperationError:error];
}


#pragma mark - Custom Getters and Setters

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

- (NSInteger)numberOfErrors
{
    return _numberOfErrors;
}

- (void)setNumberOfErrors:(NSInteger)numberOfErrors
{
    if (numberOfErrors == _numberOfErrors)
        return;

    [self willChangeValueForKey:@"numberOfErrors"];
    _numberOfErrors = numberOfErrors;
    [self didChangeValueForKey:@"numberOfErrors"];

    if (!_numberOfErrors)
        self.errorsCountString = @"";
    else
    {
        NSString *plural1 = self.numberOfErrors > 1 ? @"s" : @"";
        NSString *plural2 = self.errors.count > 1 ? @"s" : @"";
        self.errorsCountString = [NSString stringWithFormat:@"%d issue%@ in %d file%@", (int)self.numberOfErrors, plural1, (int)self.errors.count, plural2];
    }
}

@end
