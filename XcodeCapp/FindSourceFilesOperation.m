//
//  FindSourceFilesOperation.m
//  XcodeCapp
//
//  Created by Aparajita on 4/27/13.
//  Copyright (c) 2013 Cappuccino Project. All rights reserved.
//

#import "FindSourceFilesOperation.h"
#import "ProcessSourceOperation.h"
#import "CappuccinoProject.h"
#import "TaskManager.h"
#import "CappuccinoUtils.h"

NSString * const XCCNeedSourceToProjectPathMappingNotification = @"XCCNeedSourceToProjectPathMappingNotification";

@interface FindSourceFilesOperation ()

@property CappuccinoProject *cappuccinoProject;
@property TaskManager *taskManager;
@property NSString *projectPathToSearch;

@end


@implementation FindSourceFilesOperation

- (id)initWithCappuccinoProject:(CappuccinoProject *)aCappuccinoProject taskManager:(TaskManager*)aTaskManager path:(NSString *)path
{
    self = [super init];
    
    if (self)
    {
        self.cappuccinoProject = aCappuccinoProject;
        self.taskManager = aTaskManager;
        self.projectPathToSearch = path;
    }
    
    return self;
}

- (void)main
{
    [self findSourceFilesAtProjectPath:self.projectPathToSearch];
}

- (void)findSourceFilesAtProjectPath:(NSString *)aProjectPath
{
    if (self.isCancelled)
        return;

    DDLogVerbose(@"-->findSourceFiles: %@", aProjectPath);
    
    NSError *error = NULL;
    NSString *projectPath = [self.cappuccinoProject.projectPath stringByAppendingPathComponent:aProjectPath];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *urls = [fm contentsOfDirectoryAtURL:[NSURL fileURLWithPath:projectPath.stringByResolvingSymlinksInPath]
                      includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLIsSymbolicLinkKey]
                                         options:NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsSubdirectoryDescendants
                                           error:&error];

    if (!urls)
        return;

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

    for (NSURL *url in urls)
    {
        if (self.isCancelled)
            return;
        
        NSString *filename = url.lastPathComponent;

        NSString *projectRelativePath = [aProjectPath stringByAppendingPathComponent:filename];
        NSString *realPath = url.path;
        NSURL *resolvedURL = url;

        NSNumber *isDirectory, *isSymlink;
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

                    NSDictionary *info =
                          @{
                                @"cappuccinoProject":self.cappuccinoProject,
                                @"sourcePath":realPath,
                                @"projectPath":fullProjectPath,
                                @"operation":self
                           };

                    if (self.isCancelled)
                        return;

                    [center postNotificationName:XCCNeedSourceToProjectPathMappingNotification object:self userInfo:info];
                }
                else
                    DDLogVerbose(@"ignored symlinked directory: %@", projectRelativePath);
            }

            [self findSourceFilesAtProjectPath:projectRelativePath];
            continue;
        }

        if (self.isCancelled)
            return;
        
        if ([CappuccinoUtils pathMatchesIgnoredPaths:realPath cappuccinoProjectIgnoredPathPredicates:self.cappuccinoProject.ignoredPathPredicates])
            continue;

        NSString *projectSourcePath = [self.cappuccinoProject.projectPath stringByAppendingPathComponent:projectRelativePath];

        if ([CappuccinoUtils isObjjFile:filename] || [CappuccinoUtils isXibFile:filename])
        {
            NSString *processedPath;

            if ([CappuccinoUtils isObjjFile:filename])
                processedPath = [[self.cappuccinoProject shadowBasePathForProjectSourcePath:projectSourcePath] stringByAppendingPathExtension:@"h"];
            else
                processedPath = [projectSourcePath.stringByDeletingPathExtension stringByAppendingPathExtension:@"cib"];

            if (![fm fileExistsAtPath:processedPath])
                [self createProcessingOperationForProjectSourcePath:projectSourcePath];
        }
    }

    DDLogVerbose(@"<--findSourceFiles: %@", aProjectPath);
}

- (void)createProcessingOperationForProjectSourcePath:(NSString *)projectSourcePath
{
    if (self.isCancelled)
        return;

    ProcessSourceOperation *op = [[ProcessSourceOperation alloc] initWithCappuccinoProject:self.cappuccinoProject taskManager:self.taskManager sourcePath:projectSourcePath];
    
    [[NSOperationQueue currentQueue] addOperation:op];
}

@end
