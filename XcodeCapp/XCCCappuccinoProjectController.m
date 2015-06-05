//
//  CappuccinoProjectController.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/7/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "AppDelegate.h"
#import "XCCCappuccinoProjectController.h"
#import "XCCCappuccinoProject.h"
#import "CappuccinoUtils.h"
#import "CappLintUtils.h"
#import "ObjjUtils.h"
#import "LogUtils.h"
#import "XCCSourcesFinderOperation.h"
#import "XCCPPXOperation.h"
#import "XCCSourceProcessingOperation.h"
#import "XCCMainController.h"
#import "XCCOperationDataView.h"
#import "XCCOperationError.h"
#import "XCCOperationErrorDataView.h"
#import "XCCOperationErrorHeaderDataView.h"
#import "XCCTaskLauncher.h"
#import "UserDefaults.h"
#import "XcodeProjectCloser.h"
#import "XCCOperationsViewController.h"
#import "XCCErrorsViewController.h"

enum XCCLineSpecifier {
    kLineSpecifierNone,
    kLineSpecifierColon,
    kLineSpecifierMinusL,
    kLineSpecifierPlus
};
typedef enum XCCLineSpecifier XCCLineSpecifier;

@interface XCCCappuccinoProjectController ()
- (void)_handleFSEventsWithPaths:(NSArray *)paths flags:(const FSEventStreamEventFlags[])eventFlags ids:(const FSEventStreamEventId[])eventIds;
@end

void fsevents_callback(ConstFSEventStreamRef streamRef, void *userData, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[])
{
    XCCCappuccinoProjectController *controller = (__bridge  XCCCappuccinoProjectController *)userData;
    NSArray *paths = (__bridge  NSArray *)eventPaths;
    
    [controller _handleFSEventsWithPaths:paths flags:eventFlags ids:eventIds];
}



@implementation XCCCappuccinoProjectController

#pragma mark - Init methods

- (id)initWithPath:(NSString*)aPath controller:(id)aController
{
    if (self = [super init])
    {
        [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:kDefaultXCCMaxNumberOfOperations options:NSKeyValueObservingOptionNew context:NULL];
        
        self.cappuccinoProject              = [[XCCCappuccinoProject alloc] initWithPath:aPath];
        self.mainXcodeCappController        = aController;
        self->sourceProcessingOperations    = [NSMutableDictionary new];
        
        [self _reinitialize];
        
        if (self.cappuccinoProject.autoStartListening)
            [self _loadProject];
    }
    
    return self;
}

- (void)_reinitialize
{
    self->taskLauncher               = nil;
    self->operationQueue             = [[NSApp delegate] mainOperationQueue];
    self->projectPathFileDescriptor  = -1;
    
    self.operations                  = [NSMutableArray new];
    
    [self->operationQueue setMaxConcurrentOperationCount:[[[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCMaxNumberOfOperations] intValue]];
    
    [self.cappuccinoProject reinitialize];
    
    [self _reinitializeOperationsCounters];
    [self _reinitializePendingPBXOperations];
    [self _prepareXcodeSupport];
}

- (void)_reinitializeTaskLauncher
{
    NSArray *binaryPaths = [NSArray array];
    
    if ([self.cappuccinoProject.binaryPaths count])
        binaryPaths = [self.cappuccinoProject.binaryPaths valueForKeyPath:@"name"];
    
    self->taskLauncher = [[XCCTaskLauncher alloc] initWithEnvironementPaths:binaryPaths];
    
    if (!self->taskLauncher.isValid)
    {
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        
        NSRunAlertPanel(
                        self.cappuccinoProject.nickname,
                        @"XcodeCapp was unable to find all necessary executables in your environment:\n\n"
                        @"%@\n\n"
                        @"You certainly need to change the binary paths in the project settings.",
                        @"OK",
                        nil,
                        nil,
                        [self->taskLauncher.executables componentsJoinedByString:@", "]);
        
        self.cappuccinoProject.status = XCCCappuccinoProjectStatusInitialized;
    }
}



#pragma mark - Observers

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:kDefaultXCCMaxNumberOfOperations])
        [self->operationQueue setMaxConcurrentOperationCount:[[change objectForKey:NSKeyValueChangeNewKey] intValue]];
}


#pragma mark - Project State Management

- (void)_loadProject
{
    DDLogInfo(@"Loading project: %@", self.cappuccinoProject.projectPath);
    
    if (self.cappuccinoProject.status != XCCCappuccinoProjectStatusInitialized)
        return;
    
    [self _reinitialize];
    
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusLoading;
    
    [self _startListeningToNotifications];

    [self _reinitializeTaskLauncher];

    if (!self->taskLauncher.isValid)
        return;
    
    [self _populateXcodeSupportDirectory];
    [self _monitorOperationQueueCompletion];
}

- (void)_startListeningToProject
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:self.cappuccinoProject.projectPath isDirectory:nil])
    {
        NSRunAlertPanel(@"The project can’t be located.", @"It seems the project moved while XcodeCapp was not running.", @"Remove Project", nil, nil);
        
        [self.mainXcodeCappController unmanageCappuccinoProjectController:self];
        return;
    }
    
    if (self.cappuccinoProject.status != XCCCappuccinoProjectStatusStopped)
        return;

    self.cappuccinoProject.status = XCCCappuccinoProjectStatusListening;
    
    DDLogInfo(@"Start to listen project: %@", self.cappuccinoProject.projectPath);
    
    [self _startListeningToNotifications];
    
    FSEventStreamCreateFlags flags = kFSEventStreamCreateFlagUseCFTypes |
    kFSEventStreamCreateFlagWatchRoot  |
    kFSEventStreamCreateFlagIgnoreSelf |
    kFSEventStreamCreateFlagNoDefer |
    kFSEventStreamCreateFlagFileEvents;
    
    // Get a file descriptor to the project directory so we can locate it if it moves
    self->projectPathFileDescriptor = open(self.cappuccinoProject.projectPath.UTF8String, O_EVTONLY);
    
    NSArray                 *pathsToWatch   = [CappuccinoUtils getPathsToWatchForCappuccinoProject:self.cappuccinoProject];
    void                    *appPointer     = (__bridge void *)self;
    FSEventStreamContext    context         = { 0, appPointer, NULL, NULL, NULL };
    CFTimeInterval          latency         = 2.0;
    
    UInt64 lastEvenID = self.cappuccinoProject.lastEventID.unsignedLongLongValue;
    
    if (!self.cappuccinoProject.lastEventID)
        lastEvenID = kFSEventStreamEventIdSinceNow;

    self->stream = FSEventStreamCreate(NULL,
                                      &fsevents_callback,
                                      &context,
                                      (__bridge CFArrayRef) pathsToWatch,
                                      lastEvenID,
                                      latency,
                                      flags);
    
    FSEventStreamScheduleWithRunLoop(self->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    [self _startFSEventStream];

    // yep, so, this is needed in order to ensure we get a FS event, so we actually get a valid last event ID.
    [self->taskLauncher runTaskWithCommand:@"touch" arguments:@[self.cappuccinoProject.settingsPath] returnType:kTaskReturnTypeNone];

    [self.cappuccinoProject saveSettings];

    DDLogVerbose(@"FSEventStream started for paths: %@", pathsToWatch);
}

- (void)_stopListeningToProject
{
    if (self.cappuccinoProject.status == XCCCappuccinoProjectStatusStopped)
        return;
    
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusStopped;
    
    [self _stopListeningToNotifications];
    
    [self->timerOperationQueueCompletionMonitor invalidate];
    [self _cancelAllProjectRelatedOperations];
    [self.mainXcodeCappController.errorsViewController cleanProjectErrors:self];
    
    if (self->stream)
    {
        DDLogInfo(@"Stop listen project: %@", self.cappuccinoProject.projectPath);
        
        [self _updateUserDefaultsWithLastFSEventID];
        [self _stopFSEventStream];

        FSEventStreamUnscheduleFromRunLoop(self->stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        FSEventStreamInvalidate(self->stream);
        FSEventStreamRelease(self->stream);
        self->stream = NULL;
    }
    
    if (self->projectPathFileDescriptor >= 0)
    {
        close(self->projectPathFileDescriptor);
        self->projectPathFileDescriptor = -1;
    }

    [self.cappuccinoProject saveSettings];
}

- (void)_resetProject
{
    [self _stopListeningToProject];
    [self _cancelAllProjectRelatedOperations];
    [self _removeXcodeSupportDirectory];
    [self _removeXcodeProject];
    [self _reinitialize];
}


#pragma mark - XcodeSupport Management

- (BOOL)_prepareXcodeSupport
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // If either the project or the supmport directory are missing, recreate them both to ensure they are in sync
    BOOL projectExists, projectIsDirectory;
    projectExists = [fm fileExistsAtPath:self.cappuccinoProject.XcodeProjectPath isDirectory:&projectIsDirectory];
    
    BOOL supportExists, supportIsDirectory;
    supportExists = [fm fileExistsAtPath:self.cappuccinoProject.supportPath isDirectory:&supportIsDirectory];
    
    if (!projectExists || !projectIsDirectory || !supportExists)
        [self _createXcodeProject];
    
    // If the project did not exist, reset the XcodeSupport directory to force the new empty project to be populated
    if (!supportExists || !supportIsDirectory || !projectExists || ![self _isXcodeSupportCompatible])
        [self _createXcodeSupportDirectory];
    
    return projectExists && supportExists;
}

- (BOOL)_isXcodeSupportCompatible
{
    double appCompatibilityVersion = [[[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey] doubleValue];
    
    NSNumber *projectCompatibilityVersion = [NSNumber numberWithInt:[self.cappuccinoProject.version intValue]];
    
    if (projectCompatibilityVersion == nil)
    {
        DDLogVerbose(@"No compatibility version in project");
        return NO;
    }
    
    DDLogVerbose(@"XcodeCapp/project compatibility version: %0.1f/%0.1f", projectCompatibilityVersion.doubleValue, appCompatibilityVersion);
    
    return projectCompatibilityVersion.doubleValue >= appCompatibilityVersion;
}

- (void)_createXcodeProject
{
    [self _removeXcodeProject];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    [fm createDirectoryAtPath:self.cappuccinoProject.XcodeProjectPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *pbxPath = [self.cappuccinoProject.XcodeProjectPath stringByAppendingPathComponent:@"project.pbxproj"];
    
    [fm copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"project" ofType:@"pbxproj"] toPath:pbxPath error:nil];
    
    NSMutableString *content = [NSMutableString stringWithContentsOfFile:pbxPath encoding:NSUTF8StringEncoding error:nil];
    
    [content writeToFile:pbxPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    DDLogInfo(@"Xcode support project created at: %@", self.cappuccinoProject.XcodeProjectPath);
}

- (void)_removeXcodeProject
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:self.cappuccinoProject.XcodeProjectPath])
        [fm removeItemAtPath:self.cappuccinoProject.XcodeProjectPath error:nil];
}

- (void)_createXcodeSupportDirectory
{
    [self _removeXcodeSupportDirectory];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:self.cappuccinoProject.supportPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    [self.cappuccinoProject saveSettings];
    
    DDLogInfo(@".XcodeSupport directory created at: %@", self.cappuccinoProject.supportPath);
}

- (void)_removeXcodeSupportDirectory
{
    [XcodeProjectCloser closeXcodeProjectForProject:self.cappuccinoProject.projectPath];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:self.cappuccinoProject.supportPath])
        [fm removeItemAtPath:self.cappuccinoProject.supportPath error:nil];
}

- (void)_populateXcodeSupportDirectory
{
    [self _populateXcodeSupportDirectoryWithProjectRelativePath:@""];
}

- (void)_populateXcodeSupportDirectoryWithProjectRelativePath:(NSString *)path
{
    XCCSourcesFinderOperation *op = [[XCCSourcesFinderOperation alloc] initWithCappuccinoProject:self.cappuccinoProject
                                                                                    taskLauncher:self->taskLauncher
                                                                                      sourcePath:path];
    [self->operationQueue addOperation:op];
}

- (void)_removeXcodeSupportOrphanFiles
{
    NSArray         *subpaths       = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cappuccinoProject.supportPath error:nil];
    NSMutableArray  *orphanFiles    = [NSMutableArray new];
    NSFileManager   *fm             = [NSFileManager defaultManager];
    
    for (NSString *path in subpaths)
    {
        if ([CappuccinoUtils isHeaderFile:path] && ![path.lastPathComponent isEqualToString:@"xcc_general_include.h"])
        {
            NSString *sourcePath = [self.cappuccinoProject sourcePathForShadowPath:path];
            
            if (![fm fileExistsAtPath:sourcePath])
                [orphanFiles addObject:sourcePath];
        }
    }
    
    for (NSString *sourcePath in orphanFiles)
    {
        NSString *shadowBasePath            = [self.cappuccinoProject shadowBasePathForProjectSourcePath:sourcePath];
        NSString *shadowHeaderPath          = [shadowBasePath stringByAppendingPathExtension:@"h"];
        NSString *shadowImplementationPath  = [shadowBasePath stringByAppendingPathExtension:@"m"];
        
        [fm removeItemAtPath:shadowHeaderPath error:nil];
        [fm removeItemAtPath:shadowImplementationPath error:nil];
        
        [self.cappuccinoProject removeOperationErrorsRelatedToSourcePath:sourcePath errorType:XCCDefaultOperationErrorType];
        [self.mainXcodeCappController.errorsViewController reload];
        
        [self _registerPathToRemoveFromPBX:sourcePath];
    }
    
    [self.mainXcodeCappController.errorsViewController reload];
}

- (void)_updateXcodeSupportFilesWithModifiedPaths:(NSArray *)modifiedPaths
{
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusProcessing;
    
    DDLogVerbose(@"Modified files: %@", modifiedPaths);
    
    [self _removeXcodeSupportOrphanFiles];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *path in modifiedPaths)
    {
        if (![fm fileExistsAtPath:path])
            continue;

        [[self _sourceProcessingOperationsForPath:path] makeObjectsPerformSelector:@selector(cancel)];
        
        XCCSourceProcessingOperation *op = [[XCCSourceProcessingOperation alloc] initWithCappuccinoProject:self.cappuccinoProject
                                                                                              taskLauncher:self->taskLauncher
                                                                                                sourcePath:[self.cappuccinoProject projectPathForSourcePath:path]];
        
        [self->operationQueue addOperation:op];
    }
    
    [self _monitorOperationQueueCompletion];
}

- (void)_updateXcodeSupportFilesWithRenamedDirectories:(NSArray *)directories
{
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusProcessing;
    
    DDLogVerbose(@"Renamed directories: %@", directories);
    
    [self _removeXcodeSupportOrphanFiles];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *directory in directories)
    {
        // if this is the project directory itself, it is handled by another method
        if ([directory isEqualToString:self.cappuccinoProject.projectPath])
            continue;
        
        // If it doesn't exist, it's the old name. Nothing to do.
        // If it does exist, populate the project with the directory.
        
        if ([fm fileExistsAtPath:directory])
        {
            // If the directory is within the project, we can populate it directly.
            // Otherwise we have to start at the top level and repopulate everything.
            if ([directory hasPrefix:self.cappuccinoProject.projectPath])
                [self _populateXcodeSupportDirectoryWithProjectRelativePath:[self.cappuccinoProject projectRelativePathForPath:directory]];
            else
            {
                [self _populateXcodeSupportDirectory];
                
                // Since everything has been repopulated, no point in continuing
                break;
            }
        }
    }
    
    [self _monitorOperationQueueCompletion];
}


#pragma mark - Notifications Management

- (void)_startListeningToNotifications
{
    [self _stopListeningToNotifications];
    [self.mainXcodeCappController.errorsViewController startListeningToNotifications];
    [self.mainXcodeCappController.operationsViewController startListeningToNotifications];
}

- (void)_stopListeningToNotifications
{
    [self.mainXcodeCappController.errorsViewController stopListeningToNotifications];
    [self.mainXcodeCappController.operationsViewController stopListeningToNotifications];
}


#pragma mark - Operation Management

- (void)operationDidStart:(XCCAbstractOperation*)anOperation type:(NSString *)aType userInfo:(NSDictionary*)userInfo
{
    [self _addOperation:anOperation];
}

- (void)operationDidEnd:(XCCAbstractOperation*)anOperation type:(NSString *)aType userInfo:(NSDictionary*)userInfo
{
    [self _removeOperation:anOperation];
    
    if ([aType isEqualToString:XCCConversionDidEndNotification])
        [self _registerPathToAddInPBX:userInfo[@"sourcePath"]];
    
    if ([aType isEqualToString:XCCPbxCreationDidEndNotification])
    {
        self.operationsComplete++;
        [self _updateOperationsProgress];
        
        if (self.cappuccinoProject.status == XCCCappuccinoProjectStatusLoading)
        {
            self.cappuccinoProject.status = XCCCappuccinoProjectStatusStopped;
            
            [CappuccinoUtils notifyUserWithTitle:@"Project loaded" message:self.cappuccinoProject.projectPath.lastPathComponent];
            
            DDLogVerbose(@"Project finished loading");
            
            if (self.cappuccinoProject.autoStartListening)
                [self _startListeningToProject];
        }
        else
        {
            self.cappuccinoProject.status = XCCCappuccinoProjectStatusListening;
        }
    }
}

- (void)_reinitializeOperationsCounters
{
    self.operationsProgress = 1.0;
    self.operationsComplete = 0;
    self.operationsTotal    = 0;
}

- (void)_updateOperationsProgress
{
    if (self.operationsTotal == 0)
        [self _reinitializeOperationsCounters];
    
    self.operationsProgress = (float)self.operationsComplete / (float)self.operationsTotal;
    
    if (self.operationsProgress == 1.0)
        [self _reinitializeOperationsCounters];
}

- (void)_registerSourceProcessingOperation:(XCCSourceProcessingOperation *)sourceOperation
{
    if (![self->sourceProcessingOperations objectForKey:sourceOperation.sourcePath])
        [self->sourceProcessingOperations setObject:[NSMutableArray new] forKey:sourceOperation.sourcePath];

    [[self->sourceProcessingOperations objectForKey:sourceOperation.sourcePath] addObject:sourceOperation];
}

- (void)_unregisterSourceProcessingOperation:(XCCSourceProcessingOperation *)sourceOperation
{
    [[self->sourceProcessingOperations objectForKey:sourceOperation.sourcePath] removeObject:sourceOperation];

    if (![self->sourceProcessingOperations objectForKey:sourceOperation.sourcePath])
        [self->sourceProcessingOperations removeObjectForKey:sourceOperation.sourcePath];
}

- (NSArray *)_sourceProcessingOperationsForPath:(NSString *)path
{
    return [self->sourceProcessingOperations objectForKey:path];
}

- (void)_addOperation:(NSOperation *)anOperation
{
    [self.operations addObject:anOperation];
    
    if ([anOperation isKindOfClass:[XCCSourceProcessingOperation class]])
        [self _registerSourceProcessingOperation:(XCCSourceProcessingOperation *)anOperation];

    if (self.operationsTotal == 0)
        self.operationsTotal++;
    
    self.operationsTotal++;
    [self _updateOperationsProgress];
}

- (void)_removeOperation:(NSOperation *)anOperation
{
    [self.operations removeObject:anOperation];
    
    if ([anOperation isKindOfClass:[XCCSourceProcessingOperation class]])
        [self _unregisterSourceProcessingOperation:(XCCSourceProcessingOperation *)anOperation];

    self.operationsComplete++;
    [self _updateOperationsProgress];
}

- (void)_cancelAllProjectRelatedOperations
{
    self->sourceProcessingOperations = [NSMutableDictionary new];
    [[self _projectRelatedOperations] makeObjectsPerformSelector:@selector(cancel)];
}

- (NSArray*)_projectRelatedOperations
{
    return [self->operationQueue.operations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"cappuccinoProject.projectPath == %@", self.cappuccinoProject.projectPath]];
}

- (void)_monitorOperationQueueCompletion
{
    self->timerOperationQueueCompletionMonitor = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                                  target:self
                                                                                selector:@selector(_didOperationQueueMonitorTimerFire:)
                                                                                userInfo:@{@"selector" : NSStringFromSelector(@selector(_allOperationsDidComplete))}
                                                                                 repeats:NO];
}

- (void)_didOperationQueueMonitorTimerFire:(NSTimer *)timer
{
    SEL selector = NSSelectorFromString(timer.userInfo[@"selector"]);
    
    if ([[self _projectRelatedOperations] count] > 0)
    {
        [self _monitorOperationQueueCompletion];
        return;
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:selector withObject:nil];
#pragma clang diagnostic pop
}

- (void)_allOperationsDidComplete
{
    [self _updatePBX];
}


#pragma mark - FS Event Management

- (void)_startFSEventStream
{
    FSEventStreamStart(self->stream);
}

- (void)_stopFSEventStream
{
    FSEventStreamStop(self->stream);
}

- (void)_handleFSEventsWithPaths:(NSArray *)paths flags:(const FSEventStreamEventFlags[])eventFlags ids:(const FSEventStreamEventId[])eventIds
{
    [self _reinitializePendingPBXOperations];

    NSMutableArray *modifiedPaths       = [NSMutableArray new];
    NSMutableArray *renamedDirectories  = [NSMutableArray new];
    NSFileManager  *fm                  = [NSFileManager defaultManager];
    
    BOOL needUpdate = NO;
    
    for (size_t i = 0; i < paths.count; ++i)
    {
        FSEventStreamEventFlags flags       = eventFlags[i];
        NSString                *path       = [paths[i] stringByStandardizingPath];

        BOOL rootChanged = (flags & kFSEventStreamEventFlagRootChanged) != 0;
        BOOL needRescan = (flags & kFSEventStreamEventFlagMustScanSubDirs) != 0;

        if (rootChanged || needRescan)
        {
            DDLogVerbose(@"Watched path changed: %@", path);
            
            [self _handleProjectPathChange:path];
            return;
        }

        BOOL isHistoryDoneSentinalEvent = (flags & kFSEventStreamEventFlagHistoryDone) != 0;
        
        if (isHistoryDoneSentinalEvent)
        {
            DDLogVerbose(@"History done sentinal event");
            continue;
        }
        
        BOOL isMountEvent = (flags & kFSEventStreamEventFlagMount) || (flags & kFSEventStreamEventFlagUnmount);
        
        if (isMountEvent)
        {
            DDLogVerbose(@"Volume %@: %@", (flags & kFSEventStreamEventFlagMount) ? @"mounted" : @"unmounted", path);
            continue;
        }
        

        BOOL inodeMetaModified  = (flags & kFSEventStreamEventFlagItemInodeMetaMod) != 0;
        BOOL isFile             = (flags & kFSEventStreamEventFlagItemIsFile)       != 0;
        BOOL isSymlink          = (flags & kFSEventStreamEventFlagItemIsSymlink)    != 0;
        BOOL isDir              = (flags & kFSEventStreamEventFlagItemIsDir)        != 0;
        BOOL renamed            = (flags & kFSEventStreamEventFlagItemRenamed)      != 0;
        BOOL modified           = (flags & kFSEventStreamEventFlagItemModified)     != 0;
        BOOL created            = (flags & kFSEventStreamEventFlagItemCreated)      != 0;
        BOOL removed            = (flags & kFSEventStreamEventFlagItemRemoved)      != 0;
        
        if (isDir)
        {
            /*
             When a project is opened for the first time after it is created,
             we get an event where the first path is a create for the root directory.
             In that case all of the paths have been processed, and we ignore the event.
             */
            if (created && [path isEqualToString:self.cappuccinoProject.projectPath.stringByResolvingSymlinksInPath])
                return;
            
            if (renamed &&
                !(created || removed) &&
                ![CappuccinoUtils shouldIgnoreDirectoryNamed:path.lastPathComponent] &&
                ![CappuccinoUtils pathMatchesIgnoredPaths:path cappuccinoProjectIgnoredPathPredicates:self.cappuccinoProject.ignoredPathPredicates])
            {
                DDLogVerbose(@"Renamed directory: %@", path);
                
                [renamedDirectories addObject:path];
            }
            
            continue;
        }
        else if ((isFile || isSymlink) &&
                 (created || modified || renamed || removed || inodeMetaModified) &&
                 [CappuccinoUtils isSourceFile:path cappuccinoProject:self.cappuccinoProject])
        {
            DDLogVerbose(@"FSEvent accepted: %@ (%@)", path, [LogUtils dumpFSEventFlags:flags]);
            
            if ([fm fileExistsAtPath:path])
            {
                [modifiedPaths addObject:path];
            }
            else if ([CappuccinoUtils isXibFile:path])
            {
                // If a xib is deleted, delete its cib. There is no need to update when a xib is deleted,
                // it is inside a folder in Xcode, which updates automatically.
                
                if (![fm fileExistsAtPath:path])
                {
                    NSString *cibPath = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"cib"];
                    
                    if ([fm fileExistsAtPath:cibPath])
                        [fm removeItemAtPath:cibPath error:nil];
                    
                    continue;
                }
            }
            
            needUpdate = YES;
        }
        else if ((isFile || isSymlink) && (renamed || removed) && !(modified || created) && [CappuccinoUtils isCibFile:path])
        {
            DDLogVerbose(@"FSEvent accepted: %@ (%@)", path, [LogUtils dumpFSEventFlags:flags]);
            
            // If a cib is deleted, mark its xib as needing update so the cib is regenerated
            NSString *xibPath = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"xib"];
            
            if ([fm fileExistsAtPath:xibPath])
            {
                [modifiedPaths addObject:xibPath];
                needUpdate = YES;
            }
        }
        else if ((isFile || isSymlink) &&
                 (created || modified || renamed || removed || inodeMetaModified) &&
                 [CappuccinoUtils isXCCIgnoreFile:path cappuccinoProject:self.cappuccinoProject])
        {
            DDLogVerbose(@"FSEvent accepted: %@ (%@)", path, [LogUtils dumpFSEventFlags:flags]);

            [self.cappuccinoProject reloadXcodeCappIgnoreFile];
        }
    }
    
    // If directories were renamed, we take the easy way out and reset the project
    if (renamedDirectories.count)
        [self _updateXcodeSupportFilesWithRenamedDirectories:renamedDirectories];
    else if (needUpdate)
        [self _updateXcodeSupportFilesWithModifiedPaths:modifiedPaths];
}

- (void)_handleProjectPathChange:(NSString *)path
{
    NSRunAlertPanel(self.cappuccinoProject.nickname, @"The project directory changed. This project will be removed", @"OK", nil, nil, nil);

    [self.mainXcodeCappController unmanageCappuccinoProjectController:self];
}

#pragma mark - PBX management

- (void)_reinitializePendingPBXOperations
{
    self->pendingPBXOperations             = [NSMutableDictionary new];
    self->pendingPBXOperations[@"add"]     = [NSMutableArray array];
    self->pendingPBXOperations[@"remove"]  = [NSMutableArray array];
}

- (void)_registerPathToAddInPBX:(NSString *)path
{
    if (![CappuccinoUtils isObjjFile:path])
        return;
    
    [self->pendingPBXOperations[@"add"] addObject:path];
}

- (void)_registerPathToRemoveFromPBX:(NSString *)path
{
    [self->pendingPBXOperations[@"remove"] addObject:path];
}

- (void)_updatePBX
{
    XCCPPXOperation *operation = [[XCCPPXOperation alloc] initWithCappuccinoProject:self.cappuccinoProject
                                                                                       taskLauncher:self->taskLauncher
                                                                                      PBXOperations:self->pendingPBXOperations];
    
    [self->operationQueue addOperation:operation];
}

- (void)_updateUserDefaultsWithLastFSEventID
{
    UInt64 lastEventId = FSEventStreamGetLatestEventId(self->stream);
    
    // Just in case the stream callback was never called...
    if (lastEventId != 0 && lastEventId != UINT64_MAX)
    {
        self.cappuccinoProject.lastEventID = [NSNumber numberWithUnsignedLongLong:lastEventId];
        [self.cappuccinoProject saveSettings];
    }
}


#pragma mark - Third Party Application Management

- (NSString *)_managingApplicationIdenfierForFilePath:(NSString *)filePath
{
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSString *app, *type;
    
    BOOL success = [workspace getInfoForFile:filePath application:&app type:&type];
    
    return success ? app : nil;
}

- (void)launchEditorForPath:(NSString*)path line:(NSInteger)line
{
    NSString *applicationIdentifier = [self _managingApplicationIdenfierForFilePath:path];

    [self launchEditorForPath:path line:line applicationIdentifier:applicationIdentifier];
}

- (void)launchEditorForPath:(NSString*)path line:(NSInteger)line applicationIdentifier:(NSString *)applicationIdentifier
{
    if (!applicationIdentifier)
        return;
    
    NSFileManager       *fm             = [NSFileManager defaultManager];
    NSWorkspace         *workspace      = [NSWorkspace sharedWorkspace];
    NSBundle            *bundle         = [NSBundle bundleWithPath:applicationIdentifier];
    NSString            *identifier     = bundle.bundleIdentifier;
    NSString            *executablePath = nil;
    XCCLineSpecifier    lineSpecifier   = kLineSpecifierNone;
    
    if ([identifier hasPrefix:@"com.sublimetext."])
    {
        lineSpecifier = kLineSpecifierColon;
        executablePath = [[bundle sharedSupportPath] stringByAppendingPathComponent:@"bin/subl"];
    }
    else if ([identifier isEqualToString:@"com.barebones.textwrangler"])
    {
        lineSpecifier = kLineSpecifierColon;
        executablePath = [[bundle bundlePath] stringByAppendingPathComponent:@"Contents/Helpers/edit"];
    }
    else if ([identifier isEqualToString:@"com.barebones.bbedit"])
    {
        lineSpecifier = kLineSpecifierColon;
        executablePath = [[bundle bundlePath] stringByAppendingPathComponent:@"Contents/Helpers/bbedit"];
    }
    else if ([identifier isEqualToString:@"com.macromates.textmate"])  // TextMate 1.x
    {
        lineSpecifier = kLineSpecifierMinusL;
        executablePath = [[bundle sharedSupportPath] stringByAppendingPathComponent:@"Support/bin/mate"];
    }
    else if ([identifier hasPrefix:@"com.macromates.TextMate"])  // TextMate 2.x
    {
        lineSpecifier = kLineSpecifierMinusL;
        executablePath = [bundle pathForResource:@"mate" ofType:@""];
    }
    else if ([identifier isEqualToString:@"com.chocolatapp.Chocolat"])
    {
        lineSpecifier = kLineSpecifierMinusL;
        executablePath = [[bundle sharedSupportPath] stringByAppendingPathComponent:@"choc"];
    }
    else if ([identifier isEqualToString:@"org.vim.MacVim"])
    {
        lineSpecifier = kLineSpecifierPlus;
        executablePath = @"/usr/local/bin/mvim";
    }
    else if ([identifier isEqualToString:@"org.gnu.Aquamacs"])
    {
        if ([fm isExecutableFileAtPath:@"/usr/bin/aquamacs"])
            executablePath = @"/usr/bin/aquamacs";
        else if ([fm isExecutableFileAtPath:@"/usr/local/bin/aquamacs"])
            executablePath = @"/usr/local/bin/aquamacs";
    }
    else if ([identifier isEqualToString:@"com.apple.dt.Xcode"])
    {
        executablePath = [[bundle bundlePath] stringByAppendingPathComponent:@"Contents/Developer/usr/bin/xed"];
    }
    
    if (!executablePath || ![fm isExecutableFileAtPath:executablePath])
    {
        [workspace openFile:path];
        return;
    }
    
    NSArray *args;
    
    switch (lineSpecifier)
    {
        case kLineSpecifierNone:
            args = @[path];
            break;
            
        case kLineSpecifierColon:
            args = @[[NSString stringWithFormat:@"%1$@:%2$ld", path, line]];
            break;
            
        case kLineSpecifierMinusL:
            args = @[@"-l", [NSString stringWithFormat:@"%ld", line], path];
            break;
            
        case kLineSpecifierPlus:
            args = @[[NSString stringWithFormat:@"+%ld", line], path];
            break;
    }
    
    [self->taskLauncher runTaskWithCommand:executablePath arguments:args returnType:kTaskReturnTypeNone];
}


#pragma mark - Public Utilities

- (void)reinitializeProjectFromSettings
{
    DDLogVerbose(@"Saving Cappuccino configuration project %@", self.cappuccinoProject.projectPath);
    
    [self _cancelAllProjectRelatedOperations];
    [self.cappuccinoProject saveSettings];

    [self _stopListeningToProject];
    [self _reinitializeTaskLauncher];
    [self _startListeningToProject];
    
    DDLogVerbose(@"Cappuccino configuration project %@ has been saved", self.cappuccinoProject.projectPath);
}

- (void)applicationIsClosing
{
    [self _stopListeningToProject];
    [self.cappuccinoProject saveSettings];
}

- (void)cleanUpBeforeDeletion
{
    [self cancelAllOperations:self];
    [self _stopListeningToNotifications];
    [self _stopListeningToProject];
    [self _removeXcodeProject];
    [self _removeXcodeSupportDirectory];
}


#pragma mark - Actions

- (IBAction)cancelAllOperations:(id)aSender
{
    [self _cancelAllProjectRelatedOperations];
    [self.operations removeAllObjects];
    [self.mainXcodeCappController.operationsViewController reload];
}

- (IBAction)cancelOperation:(id)sender
{
//    XCCSourceProcessingOperation *operation = [[self _projectRelatedOperations] objectAtIndex:[self.mainWindowController.operationTableView rowForView:sender]];
//    [operation cancel];
}

- (IBAction)resetProject:(id)aSender
{
    [self _resetProject];
    [self _loadProject];
}

- (IBAction)openProjectInXcode:(id)aSender
{
    BOOL            isDirectory;
    BOOL            isOpened    = YES;
    NSFileManager   *fm         = [NSFileManager defaultManager];
    BOOL            exists      = [fm fileExistsAtPath:self.cappuccinoProject.XcodeProjectPath isDirectory:&isDirectory];
    
    if (exists && isDirectory)
    {
        DDLogVerbose(@"Opening Xcode project at: %@", self.cappuccinoProject.XcodeProjectPath);
        
        isOpened = [[NSWorkspace sharedWorkspace] openFile:self.cappuccinoProject.XcodeProjectPath];
    }
    
    if (!exists || !isDirectory || !isOpened)
    {
        NSString *text;
        
        if (!isOpened)
            text = @"The project exists, but failed to open.";
        else
            text = [NSString stringWithFormat:@"%@ %@.", self.cappuccinoProject.XcodeProjectPath, !exists ? @"does not exist" : @"is not an Xcode project"];
        
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        NSInteger response = NSRunAlertPanel(@"The project could not be opened.", @"%@\n\nWould you like to regenerate the project?", @"Yes", @"No", nil, text);
        
        if (response == NSAlertFirstButtonReturn)
            [self resetProject:self];
    }
}

- (IBAction)openProjectInFinder:(id)sender
{
    [[NSWorkspace sharedWorkspace] openFile:self.cappuccinoProject.projectPath];
}

- (IBAction)openProjectInEditor:(id)sender
{
    NSFileManager   *fm         = [NSFileManager defaultManager];
    NSArray         *contents   = [fm contentsOfDirectoryAtPath:self.cappuccinoProject.projectPath error:nil];
    NSString        *firstObjjFile;
    
    for (NSString *file in contents)
    {
        if ([[file pathExtension] isEqualToString:@"j"])
        {
            firstObjjFile = file;
            break;
        }
    }
    
    if (!firstObjjFile)
        return;
    
    NSString *applicationIdentifier = [self _managingApplicationIdenfierForFilePath:[self.cappuccinoProject.projectPath stringByAppendingPathComponent:firstObjjFile]];
    
    if (!applicationIdentifier)
        return;
    
    [self launchEditorForPath:self.cappuccinoProject.projectPath line:0 applicationIdentifier:applicationIdentifier];
}

- (IBAction)openProjectInTerminal:(id)sender;
{
    NSString *s = [NSString stringWithFormat:@"tell application \"Terminal\"\n do script \"cd %@\" \n activate\n end tell", self.cappuccinoProject.projectPath];
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:s];
    [script executeAndReturnError:nil];
}


- (IBAction)switchProjectListeningStatus:(id)sender
{
    if (self.cappuccinoProject.status == XCCCappuccinoProjectStatusInitialized)
    {
        [self _loadProject];
        self.cappuccinoProject.autoStartListening = YES;
    }
    else if (self.cappuccinoProject.status == XCCCappuccinoProjectStatusStopped)
    {
        [self _startListeningToProject];
        self.cappuccinoProject.autoStartListening = YES;
    }
    else
    {
        [self _stopListeningToProject];
        self.cappuccinoProject.autoStartListening = NO;
    }
}

@end


