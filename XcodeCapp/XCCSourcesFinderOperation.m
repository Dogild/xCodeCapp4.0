//
//  FindSourceFilesOperation.m
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import "XCCSourcesFinderOperation.h"
#import "XCCSourceProcessingOperation.h"
#import "XCCTaskLauncher.h"

NSString * const XCCSourcesFinderOperationDidStartNotification = @"XCCSourcesFinderOperationDidStartNotification";
NSString * const XCCSourcesFinderOperationDidEndNotification = @"XCCSourcesFinderOperationDidEndNotification";
NSString * const XCCNeedSourceToProjectPathMappingNotification = @"XCCNeedSourceToProjectPathMappingNotification";


@implementation XCCSourcesFinderOperation


#pragma mark - Initialization

- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)aCappuccinoProject taskLauncher:(XCCTaskLauncher*)aTaskLauncher sourcePath:(NSString *)sourcePath
{
    if (self = [super initWithCappuccinoProject:aCappuccinoProject taskLauncher:aTaskLauncher])
    {
        self->searchPath = sourcePath;
    }
    
    return self;
}


#pragma mark - Utilities

- (NSArray*)_findSourceFilesAtProjectPath:(NSString *)aProjectPath
{
    if (self.isCancelled)
        return @[];
    
    NSError         *error          = NULL;
    NSString        *projectPath    = [self.cappuccinoProject.projectPath stringByAppendingPathComponent:aProjectPath];
    NSFileManager   *fm             = [NSFileManager defaultManager];
    NSMutableArray  *sourcePaths    = [NSMutableArray array];
    
    NSArray *urls = [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:projectPath.stringByResolvingSymlinksInPath]
                      includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey]
                                         options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                           error:&error];

    if (!urls)
        return @[];

    for (NSURL *url in urls)
    {
        if (self.isCancelled)
            return @[];

        NSString    *filename               = url.lastPathComponent;
        NSString    *projectRelativePath    = [aProjectPath stringByAppendingPathComponent:filename];
        NSString    *realPath               = url.path;
        NSURL       *resolvedURL            = url;
        NSNumber    *isDirectory;
        NSNumber    *isSymlink;

        [url getResourceValue:&isSymlink forKey:NSURLIsSymbolicLinkKey error:nil];

        if (isSymlink.boolValue == YES)
        {
            resolvedURL = [url URLByResolvingSymlinksInPath];

            if ([resolvedURL checkResourceIsReachableAndReturnError:nil])
            {
                filename = resolvedURL.lastPathComponent;
                realPath = resolvedURL.path;
            }
            else
                continue;
        }

        [resolvedURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if (isDirectory.boolValue == YES)
        {
            if ([CappuccinoUtils shouldIgnoreDirectoryNamed:filename])
            {
                DDLogVerbose(@"ignored symlinked directory: %@", projectRelativePath);
                continue;
            }

            // If the resolved path is not within the project directory and is not ignored, add a mapping to it
            // so we can map the resolved path back to the project directory later.
            if (isSymlink.boolValue == YES)
            {
                NSString *fullProjectPath = [self.cappuccinoProject.projectPath stringByAppendingPathComponent:projectRelativePath];

                if (![realPath hasPrefix:fullProjectPath] && ![CappuccinoUtils pathMatchesIgnoredPaths:fullProjectPath cappuccinoProjectIgnoredPathPredicates:self.cappuccinoProject.ignoredPathPredicates])
                {
                    DDLogVerbose(@"symlinked directory: %@ -> %@", projectRelativePath, realPath);

                    NSMutableDictionary *info   = [self operationInformations];
                    info[@"sourcePath"]         = realPath;
                    info[@"projectPath"]        = fullProjectPath;

                    [self dispatchNotificationName:XCCNeedSourceToProjectPathMappingNotification userInfo:info];
                }
                else
                    DDLogVerbose(@"ignored symlinked directory: %@", projectRelativePath);
            }

            DDLogVerbose(@"found directory. checking for source files: %@", filename);

            [sourcePaths addObjectsFromArray:[self _findSourceFilesAtProjectPath:projectRelativePath]];
            continue;
        }

        if ([CappuccinoUtils pathMatchesIgnoredPaths:realPath cappuccinoProjectIgnoredPathPredicates:self.cappuccinoProject.ignoredPathPredicates])
            continue;

        NSString *projectSourcePath = [self.cappuccinoProject.projectPath stringByAppendingPathComponent:projectRelativePath];

        if ([CappuccinoUtils isObjjFile:filename] || [CappuccinoUtils isXibFile:filename])
        {
            DDLogVerbose(@"found source file: %@", filename);

            NSString *processedPath;

            if ([CappuccinoUtils isObjjFile:filename])
                processedPath = [[self.cappuccinoProject shadowBasePathForProjectSourcePath:projectSourcePath] stringByAppendingPathExtension:@"h"];
            else
                processedPath = [projectSourcePath.stringByDeletingPathExtension stringByAppendingPathExtension:@"cib"];

            if (![fm fileExistsAtPath:processedPath])
                [sourcePaths addObject:projectSourcePath];
        }
    }
    
    return sourcePaths;
}


#pragma mark - NSOperation API

- (void)main
{
    @try
    {
        [self dispatchNotificationName:XCCSourcesFinderOperationDidStartNotification userInfo:@{@"cappuccinoProject": self.cappuccinoProject, @"sourcePaths" : @[]}];
        NSArray *sourcesPaths = [self _findSourceFilesAtProjectPath:self->searchPath];
        [self dispatchNotificationName:XCCSourcesFinderOperationDidEndNotification userInfo:@{@"cappuccinoProject": self.cappuccinoProject, @"sourcePaths" : sourcesPaths}];
    }
    @catch (NSException *exception)
    {
        DDLogVerbose(@"Finding source files failed: %@", exception);
    }
}

@end
