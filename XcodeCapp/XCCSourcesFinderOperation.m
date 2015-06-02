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

NSString * const XCCNeedSourceToProjectPathMappingNotification = @"XCCNeedSourceToProjectPathMappingNotification";

@interface XCCSourcesFinderOperation ()
@property XCCTaskLauncher   *taskLauncher;
@property NSString          *projectPathToSearch;
@end


@implementation XCCSourcesFinderOperation

- (id)initWithCappuccinoProject:(XCCCappuccinoProject *)aCappuccinoProject taskLauncher:(XCCTaskLauncher*)aTaskLauncher sourcePath:(NSString *)sourcePath
{
    self = [super init];
    
    if (self)
    {
        self.cappuccinoProject = aCappuccinoProject;
        self.taskLauncher = aTaskLauncher;
        self.projectPathToSearch = sourcePath;
    }
    
    return self;
}

- (void)main
{
    @try
    {
        [self findSourceFilesAtProjectPath:self.projectPathToSearch];
    }
    @catch (NSException *exception)
    {
        DDLogVerbose(@"Finding source files failed: %@", exception);
    }
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
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [center postNotificationName:XCCNeedSourceToProjectPathMappingNotification object:self userInfo:info];
                    });
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

    XCCSourceProcessingOperation *op = [[XCCSourceProcessingOperation alloc] initWithCappuccinoProject:self.cappuccinoProject taskLauncher:self.taskLauncher sourcePath:projectSourcePath];
    
    [[NSOperationQueue currentQueue] addOperation:op];
}

@end
