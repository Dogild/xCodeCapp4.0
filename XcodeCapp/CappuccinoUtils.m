//
//  CappuccinoUtils.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/7/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "CappuccinoUtils.h"
#import "CappuccinoProject.h"
#import "XcodeProjectCloser.h"

// The regex above is used with this predicate for testing.
static NSPredicate * XCCDirectoriesToIgnorePredicate = nil;

// When scanning the project, we immediately ignore directories that match this regex.
static NSString * const XCCDirectoriesToIgnorePattern = @"^(?:Build|F(?:rameworks|oundation)|AppKit|Objective-J|(?:Browser|CommonJS)\\.environment|Resources|XcodeSupport|.+\\.xcodeproj)$";

// An array of the default predicates used to ignore paths.
static NSArray *XCCDefaultIgnoredPathPredicates = nil;

@implementation CappuccinoUtils

+ (void)initialize
{
    if (self != [CappuccinoUtils class])
        return;
    
    XCCDirectoriesToIgnorePredicate = [NSPredicate predicateWithFormat:@"SELF matches %@", XCCDirectoriesToIgnorePattern];
    
    NSArray *defaultIgnoredPaths = @[
                                     @"*/Frameworks/",
                                     @"!*/Frameworks/Debug/",
                                     @"!*/Frameworks/Source/",
                                     @"*/AppKit/",
                                     @"*/Foundation/",
                                     @"*/Objective-J/",
                                     @"*/*.environment/",
                                     @"*/Build/",
                                     @"*/*.xcodeproj/",
                                     @"*/.*/",
                                     @"*/NS_*.j",
                                     @"*/main.j",
                                     @"*/.*",
                                     @"!*/.xcodecapp-ignore"
                                     ];
    
    XCCDefaultIgnoredPathPredicates = [self parseIgnorePaths:defaultIgnoredPaths];
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

+ (BOOL)isXCCIgnoreFile:(NSString *)path cappuccinoProjectXcodecappIgnorePath:(NSString*)xcodecappIgnorePath
{
    return [path isEqualToString:xcodecappIgnorePath];
}

+ (BOOL)isSourceFile:(NSString *)path cappuccinoProject:(CappuccinoProject*)aCappuccinoProject
{
    return ([self isXibFile:path] || [self isObjjFile:path] || [self isXCCIgnoreFile:path cappuccinoProjectXcodecappIgnorePath:aCappuccinoProject.xcodecappIgnorePath]) && ![self pathMatchesIgnoredPaths:path cappuccinoProjectIgnoredPathPredicates:aCappuccinoProject.ignoredPathPredicates];
}

+ (BOOL)shouldIgnoreDirectoryNamed:(NSString *)filename
{
    return [XCCDirectoriesToIgnorePredicate evaluateWithObject:filename];
}

+ (BOOL)pathMatchesIgnoredPaths:(NSString*)aPath cappuccinoProjectIgnoredPathPredicates:(NSMutableArray*)cappuccinoProjectIgnoredPathPredicates
{
    BOOL ignore = NO;
    
    NSMutableArray *ignoredPathPredicates = [XCCDefaultIgnoredPathPredicates mutableCopy];
    [ignoredPathPredicates addObjectsFromArray:cappuccinoProjectIgnoredPathPredicates];
    
    for (NSDictionary *ignoreInfo in ignoredPathPredicates)
    {
        BOOL matches = [ignoreInfo[@"predicate"] evaluateWithObject:aPath];
        
        if (matches)
            ignore = [ignoreInfo[@"exclude"] boolValue];
    }
    
    return ignore;
}

+ (NSArray *)parseIgnorePaths:(NSArray *)paths
{
    NSMutableArray *parsedPaths = [NSMutableArray array];
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceCharacterSet];
    
    for (NSString *pattern in paths)
    {
        if ([pattern stringByTrimmingCharactersInSet:whitespace].length == 0)
            continue;
        
        NSString *regexPattern = [self globToRegexPattern:pattern];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF matches %@", regexPattern];
        [parsedPaths addObject:@{ @"predicate": predicate, @"exclude": @([pattern characterAtIndex:0] != '!') }];
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

+ (NSArray *)getPathsToWatchForCappuccinoProject:(CappuccinoProject*)aCappuccinoProject
{
    NSMutableArray *pathsToWatch = [NSMutableArray arrayWithObject:aCappuccinoProject.projectPath];
    NSArray *otherPathsToWatch = @[@"", @"Frameworks/Debug", @"Frameworks/Source"];
    NSFileManager *fm = [NSFileManager defaultManager];
    
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

+ (void)watchSymlinkedDirectoriesAtPath:(NSString *)projectPath pathsToWatch:(NSMutableArray *)pathsToWatch cappuccinoProject:(CappuccinoProject*)aCappuccinoProject
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

+ (void)removeAllCibsAtPath:(NSString *)path
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSArray *paths = [fm contentsOfDirectoryAtPath:path error:nil];
    
    for (NSString *filePath in paths)
    {
        if ([self isCibFile:filePath])
            [fm removeItemAtPath:[path stringByAppendingPathComponent:filePath] error:nil];
    }
}

+ (void)removeSupportFilesForCappuccinoProject:(CappuccinoProject*)aCappuccinoProject
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    [XcodeProjectCloser closeXcodeProjectForProject:aCappuccinoProject.projectPath];
    
    [fm removeItemAtPath:aCappuccinoProject.xcodeProjectPath error:nil];
    [fm removeItemAtPath:aCappuccinoProject.supportPath error:nil];
}

+ (void)notifyUserWithTitle:(NSString *)aTitle message:(NSString *)aMessage
{
    NSUserNotification *note = [NSUserNotification new];
    
    note.title = aTitle;
    note.informativeText = aMessage;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:note];
}

@end
