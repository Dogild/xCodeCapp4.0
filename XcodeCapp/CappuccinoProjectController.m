//
//  CappuccinoProjectController.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/7/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "CappuccinoProjectController.h"
#import "CappuccinoProject.h"
#import "CappuccinoUtils.h"
#import "FindSourceFilesOperation.h"
#import "LogUtils.h"
#import "MainController.h"
#import "OperationViewCell.h"
#import "ProcessSourceOperation.h"
#import "TaskManager.h"
#import "UserDefaults.h"

@interface CappuccinoProjectController ()

@property NSFileManager *fm;

// A queue for threaded operations to perform
@property NSOperationQueue *operationQueue;

@property FSEventStreamRef stream;

// The last FSEvent id we received. This is stored in the user prefs
// so we can get all changes since the last time XcodeCapp was launched.
@property NSNumber *lastEventId;

// We keep a file descriptor open for the project directory
// so we can locate it if it moves.
@property int projectPathFileDescriptor;

// A list of files currently processing
@property NSMutableArray *currentOperations;

// Coalesces the modifications that have to be made to the Xcode project
// after changes are made to source files. Keys are the actions "add" or "remove",
// values are arrays of full paths to source files that need to be added or removed.
@property NSMutableDictionary *pbxOperations;

- (void)handleFSEventsWithPaths:(NSArray *)paths flags:(const FSEventStreamEventFlags[])eventFlags ids:(const FSEventStreamEventId[])eventIds;

@end


void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[])
{
    CappuccinoProjectController *controller = (__bridge  CappuccinoProjectController *)userData;
    NSArray *paths = (__bridge  NSArray *)eventPaths;
    
    [controller handleFSEventsWithPaths:paths flags:eventFlags ids:eventIds];
}



@implementation CappuccinoProjectController

#pragma mark - Init methods

- (id)initWithPath:(NSString*)aPath
{
    self = [super init];
    
    if (self)
    {
        self.fm = [NSFileManager defaultManager];
        self.cappuccinoProject = [[CappuccinoProject alloc] initWithPath:aPath];
                
        [self _init];
    }
    
    return self;
}

- (void)_init
{
    self.taskManager = nil;
    
    self.operationQueue = [NSOperationQueue new];
    
    self.currentOperations = [NSMutableArray array];
    
    [self _initPbxOperations];
    [self.cappuccinoProject _init];
    
    self.lastEventId = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCLastEventId];
    
    self.projectPathFileDescriptor = -1;
}

- (void)_initPbxOperations
{
    self.pbxOperations = [NSMutableDictionary new];
    
    self.pbxOperations[@"add"] = [NSMutableArray array];
    self.pbxOperations[@"remove"] = [NSMutableArray array];
}

- (TaskManager*)makeTaskManager
{
    NSArray *environementPaths;
    
    if (![self.cappuccinoProject.environementsPaths count])
        environementPaths = [NSArray array];
    else
        environementPaths = [self.cappuccinoProject.environementsPaths valueForKeyPath:@"name"];
    
    TaskManager *taskManager = [[TaskManager alloc] initWithEnvironementPaths:environementPaths];
    
    if (!taskManager.isValid)
    {
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        
        NSRunAlertPanel(
                        @"Executables are missing.",
                        @"Please make sure that each one of these executables:\n\n"
                        @"%@\n\n"
                        @"(or a symlink to it) is within one these directories:\n\n"
                        @"%@\n\n"
                        @"They do not all have to be in the same directory.",
                        @"Quit",
                        nil,
                        nil,
                        [taskManager.executables componentsJoinedByString:@"\n"],
                        [taskManager.environmentPaths componentsJoinedByString:@"\n"]);
    }
    
    return taskManager;
}

#pragma mark - Loading methods

- (void)loadProject
{
    DDLogInfo(@"Loading project: %@", self.cappuccinoProject.projectPath);
    
    if (self.cappuccinoProject.isProjectLoaded)
    {
        [self startListenProject];
        return;
    }
    
    [self _init];
    
    self.cappuccinoProject.isLoadingProject = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCProjectDidStartLoadingNotification object:self];
    
    [self initObservers];
    [self prepareXcodeSupport];
    [self.cappuccinoProject initEnvironmentPaths];
    
    self.taskManager = [self makeTaskManager];
    
    [self populateXcodeProject];
    [self populatexCodeCappTargetedFiles];
    [self waitForOperationQueueToFinishWithSelector:@selector(projectDidFinishLoading)];
}

/*!
 Create Xcode project and .XcodeSupport directory if necessary.
 
 @return YES if both exist
 */
- (BOOL)prepareXcodeSupport
{
    // If either the project or the supmport directory are missing, recreate them both to ensure they are in sync
    BOOL projectExists, projectIsDirectory;
    projectExists = [self.fm fileExistsAtPath:self.cappuccinoProject.xcodeProjectPath isDirectory:&projectIsDirectory];
    
    BOOL supportExists, supportIsDirectory;
    supportExists = [self.fm fileExistsAtPath:self.cappuccinoProject.supportPath isDirectory:&supportIsDirectory];
    
    if (!projectExists || !projectIsDirectory || !supportExists)
        [self createXcodeProject];
    
    // If the project did not exist, reset the XcodeSupport directory to force the new empty project to be populated
    if (!supportExists || !supportIsDirectory || !projectExists || ![self xCodeSupportIsCompatible])
        [self createXcodeSupportDirectory];
    
    return projectExists && supportExists;
}

- (BOOL)xCodeSupportIsCompatible
{
    double appCompatibilityVersion = [[[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey] doubleValue];
    
    NSNumber *projectCompatibilityVersion = [self.cappuccinoProject settingValueForKey:XCCCompatibilityVersionKey];
    
    if (projectCompatibilityVersion == nil)
    {
        DDLogVerbose(@"No compatibility version in project");
        return NO;
    }
    
    DDLogVerbose(@"XcodeCapp/project compatibility version: %0.1f/%0.1f", projectCompatibilityVersion.doubleValue, appCompatibilityVersion);
    
    return projectCompatibilityVersion.doubleValue >= appCompatibilityVersion;
}

- (void)createXcodeProject
{
    if ([self.fm fileExistsAtPath:self.cappuccinoProject.xcodeProjectPath])
        [self.fm removeItemAtPath:self.cappuccinoProject.xcodeProjectPath error:nil];
    
    [self.fm createDirectoryAtPath:self.cappuccinoProject.xcodeProjectPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *pbxPath = [self.cappuccinoProject.xcodeProjectPath stringByAppendingPathComponent:@"project.pbxproj"];
    
    [self.fm copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"project" ofType:@"pbxproj"] toPath:pbxPath error:nil];
    
    NSMutableString *content = [NSMutableString stringWithContentsOfFile:pbxPath encoding:NSUTF8StringEncoding error:nil];
    
    [content writeToFile:pbxPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    DDLogInfo(@"Xcode support project created at: %@", self.cappuccinoProject.xcodeProjectPath);
}


- (void)createXcodeSupportDirectory
{
    if ([self.fm fileExistsAtPath:self.cappuccinoProject.supportPath])
        [self.fm removeItemAtPath:self.cappuccinoProject.supportPath error:nil];
    
    [self.fm createDirectoryAtPath:self.cappuccinoProject.supportPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:[self.cappuccinoProject defaultSettings]
                                                              format:NSPropertyListXMLFormat_v1_0
                                                    errorDescription:nil];
    
    [data writeToFile:self.cappuccinoProject.infoPlistPath atomically:YES];
    
    DDLogInfo(@".XcodeSupport directory created at: %@", self.cappuccinoProject.supportPath);
}

- (void)populateXcodeProject
{
    // Populate with all non-framework code
    [self populateXcodeProjectWithProjectRelativePath:@""];
    
    // Populate with any user source debug frameworks
    [self populateXcodeProjectWithProjectRelativePath:@"Frameworks/Debug"];
    
    // Populate with any source frameworks
    [self populateXcodeProjectWithProjectRelativePath:@"Frameworks/Source"];
    
    // Populate resources
    [self populateXcodeProjectWithProjectRelativePath:@"Resources"];
}

- (void)populateXcodeProjectWithProjectRelativePath:(NSString *)path
{
    FindSourceFilesOperation *op = [[FindSourceFilesOperation alloc] initWithCappuccinoProject:self.cappuccinoProject taskManager:self.taskManager path:path];
    [self.operationQueue addOperation:op];
}

- (void)populatexCodeCappTargetedFiles
{
    NSDirectoryEnumerator *filesOfProject = [self.fm enumeratorAtPath:self.cappuccinoProject.projectPath];
    NSString *filename;
    
    self.cappuccinoProject.xCodeCappTargetedFiles = [NSMutableArray array];
    
    while ((filename = [filesOfProject nextObject] )) {
        
        NSString *fullPath = [self.cappuccinoProject.projectPath stringByAppendingPathComponent:filename];
        
        if (![CappuccinoUtils isSourceFile:fullPath cappuccinoProject:self.cappuccinoProject])
            continue;
        
        [self.cappuccinoProject.xCodeCappTargetedFiles addObject:fullPath];
    }
}

#pragma mark - Observers methods

- (void)initObservers
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self selector:@selector(addSourceToProjectPathMappingHandler:) name:XCCNeedSourceToProjectPathMappingNotification object:nil];
    
    [center addObserver:self selector:@selector(sourceConversionDidStartHandler:) name:XCCConversionDidStartNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionDidEndHandler:) name:XCCConversionDidEndNotification object:nil];
    
    
    [center addObserver:self selector:@selector(sourceConversionDidGenerateErrorHandler:) name:XCCConversionDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionDidGenerateErrorHandler:) name:XCCObjjDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionDidGenerateErrorHandler:) name:XCCCappLintDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionDidGenerateErrorHandler:) name:XCCObjj2ObjcSkeletonDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionDidGenerateErrorHandler:) name:XCCNib2CibDidGenerateErrorNotification object:nil];
}

- (BOOL)notificationBelongsToCurrentProject:(NSNotification *)note
{
    return note.userInfo[@"cappuccinoProject"] == self.cappuccinoProject;
}

- (void)addSourceToProjectPathMappingHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self performSelectorOnMainThread:@selector(addSourceToProjectPathMapping:) withObject:note waitUntilDone:NO];
}

- (void)addSourceToProjectPathMapping:(NSNotification *)note
{
    NSDictionary *info = note.userInfo;
    NSString *sourcePath = info[@"sourcePath"];
    
    DDLogVerbose(@"Adding source to project mapping: %@ -> %@", sourcePath, info[@"projectPath"]);
    
    self.cappuccinoProject.projectPathsForSourcePaths[info[@"sourcePath"]] = info[@"projectPath"];
}

- (void)sourceConversionDidStartHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self performSelectorOnMainThread:@selector(sourceConversionDidStart:) withObject:note waitUntilDone:NO];
}

- (void)sourceConversionDidStart:(NSNotification *)note
{
    NSDictionary *info = note.userInfo;
    NSString *sourcePath = info[@"sourcePath"];
    
    DDLogVerbose(@"%@ %@", NSStringFromSelector(_cmd), sourcePath);
    
    [self.currentOperations addObject:note.object];
    [self.mainController.operationTableView reloadData];
    
    //[self pruneProcessingErrorsForProjectPath:sourcePath];
}

- (void)sourceConversionDidEndHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self performSelectorOnMainThread:@selector(sourceConversionDidEnd:) withObject:note waitUntilDone:NO];
}

- (void)sourceConversionDidEnd:(NSNotification *)note
{
    NSDictionary *info = note.userInfo;
    NSString *path = info[@"sourcePath"];
    
    [self.currentOperations removeObject:note.object];
    [self.mainController.operationTableView reloadData];
    
    if ([CappuccinoUtils isObjjFile:path])
        [self.pbxOperations[@"add"] addObject:path];
    
    DDLogVerbose(@"%@ %@", NSStringFromSelector(_cmd), path);
}

- (void)sourceConversionDidGenerateErrorHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self performSelectorOnMainThread:@selector(sourceConversionDidGenerateError:) withObject:note waitUntilDone:NO];
}

- (void)sourceConversionDidGenerateError:(NSNotification *)note
{
    NSMutableDictionary *info = [note.userInfo mutableCopy];
    
    DDLogVerbose(@"%@ %@", NSStringFromSelector(_cmd), info[@"sourcePath"]);
    
    //[self.errorListController addObject:info];
}


#pragma mark - Events methods

- (void)startListenProject
{
    if (self.stream)
        return;
    
    DDLogInfo(@"Start to listen project: %@", self.cappuccinoProject.projectPath);
    
    [self stopListenProject];
    
    FSEventStreamCreateFlags flags = kFSEventStreamCreateFlagUseCFTypes |
                                     kFSEventStreamCreateFlagWatchRoot  |
                                     kFSEventStreamCreateFlagIgnoreSelf |
                                     kFSEventStreamCreateFlagNoDefer |
                                     kFSEventStreamCreateFlagFileEvents;
    
    // Get a file descriptor to the project directory so we can locate it if it moves
    self.projectPathFileDescriptor = open(self.cappuccinoProject.projectPath.UTF8String, O_EVTONLY);
    
    NSArray *pathsToWatch = [CappuccinoUtils getPathsToWatchForCappuccinoProject:self.cappuccinoProject];
    
    void *appPointer = (__bridge void *)self;
    FSEventStreamContext context = { 0, appPointer, NULL, NULL, NULL };
    CFTimeInterval latency = 2.0;
    UInt64 lastEventId = self.lastEventId.unsignedLongLongValue;
    
    self.stream = FSEventStreamCreate(NULL,
                                      &fsevents_callback,
                                      &context,
                                      (__bridge CFArrayRef) pathsToWatch,
                                      lastEventId,
                                      latency,
                                      flags);
    
    FSEventStreamScheduleWithRunLoop(self.stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    [self startFSEventStream];
    
    DDLogVerbose(@"FSEventStream started for paths: %@", pathsToWatch);
}

- (void)startFSEventStream
{
    if (self.stream && !self.cappuccinoProject.isListeningProject)
    {
        FSEventStreamStart(self.stream);
        self.cappuccinoProject.isListeningProject = YES;
    }
}

- (void)stopListenProject
{
    if (self.stream)
    {
        DDLogInfo(@"Stop listen project: %@", self.cappuccinoProject.projectPath);
        
        [self updateUserDefaultsWithLastEventId];
        [self stopFSEventStream];
        FSEventStreamUnscheduleFromRunLoop(self.stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
        FSEventStreamInvalidate(self.stream);
        FSEventStreamRelease(self.stream);
        self.stream = NULL;
    }
    
    if (self.projectPathFileDescriptor >= 0)
    {
        close(self.projectPathFileDescriptor);
        self.projectPathFileDescriptor = -1;
    }
}

- (void)stopFSEventStream
{
    if (self.stream && self.cappuccinoProject.isListeningProject)
    {
        FSEventStreamStop(self.stream);
        self.cappuccinoProject.isListeningProject = NO;
    }
}

- (void)handleFSEventsWithPaths:(NSArray *)paths flags:(const FSEventStreamEventFlags[])eventFlags ids:(const FSEventStreamEventId[])eventIds
{
    DDLogVerbose(@"FSEvents: %ld path(s)", paths.count);
    [self _initPbxOperations];
    
    NSMutableArray *modifiedPaths = [NSMutableArray new];
    NSMutableArray *renamedDirectories = [NSMutableArray new];
    
    BOOL needUpdate = NO;
    
    for (size_t i = 0; i < paths.count; ++i)
    {
        FSEventStreamEventFlags flags = eventFlags[i];
        NSString *path = [paths[i] stringByStandardizingPath];
        
        BOOL rootChanged = (flags & kFSEventStreamEventFlagRootChanged) != 0;
        
        if (rootChanged)
        {
            DDLogVerbose(@"Watched path changed: %@", path);
            
            [self resetProjectForWatchedPath:path];
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
        
        BOOL needRescan = (flags & kFSEventStreamEventFlagMustScanSubDirs) != 0;
        
        if (needRescan)
        {
            // A rescan requires a reset
            [self resetProjectForWatchedPath:path];
            
            return;
        }

        BOOL inodeMetaModified = (flags & kFSEventStreamEventFlagItemInodeMetaMod) != 0;
        BOOL isFile = (flags & kFSEventStreamEventFlagItemIsFile) != 0;
        BOOL isDir = (flags & kFSEventStreamEventFlagItemIsDir) != 0;
        BOOL renamed = (flags & kFSEventStreamEventFlagItemRenamed) != 0;
        BOOL modified = (flags & kFSEventStreamEventFlagItemModified) != 0;
        BOOL created = (flags & kFSEventStreamEventFlagItemCreated) != 0;
        BOOL removed = (flags & kFSEventStreamEventFlagItemRemoved) != 0;
        
        DDLogVerbose(@"FSEvent: %@ (%@)", path, [LogUtils dumpFSEventFlags:flags]);
        
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
        else if (isFile &&
                 (created || modified || renamed || removed || inodeMetaModified) &&
                 [CappuccinoUtils isSourceFile:path cappuccinoProject:self.cappuccinoProject])
        {
            DDLogVerbose(@"FSEvent accepted");
            
            if ([self.fm fileExistsAtPath:path])
            {
                [modifiedPaths addObject:path];
            }
            else if ([CappuccinoUtils isXibFile:path])
            {
                // If a xib is deleted, delete its cib. There is no need to update when a xib is deleted,
                // it is inside a folder in Xcode, which updates automatically.
                
                if (![self.fm fileExistsAtPath:path])
                {
                    NSString *cibPath = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"cib"];
                    
                    if ([self.fm fileExistsAtPath:cibPath])
                        [self.fm removeItemAtPath:cibPath error:nil];
                    
                    continue;
                }
            }
            
            needUpdate = YES;
        }
        else if (isFile && (renamed || removed) && !(modified || created) && [CappuccinoUtils isCibFile:path])
        {
            // If a cib is deleted, mark its xib as needing update so the cib is regenerated
            NSString *xibPath = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"xib"];
            
            if ([self.fm fileExistsAtPath:xibPath])
            {
                [modifiedPaths addObject:xibPath];
                needUpdate = YES;
            }
        }
    }
    
    // If directories were renamed, we take the easy way out and reset the project
    if (renamedDirectories.count)
        [self handleRenamedDirectories:renamedDirectories];
    else if (needUpdate)
        [self updateSupportFilesWithModifiedPaths:modifiedPaths];
}


- (void)updateSupportFilesWithModifiedPaths:(NSArray *)modifiedPaths
{
    // Make sure we don't get any more events while handling these events
    [self stopFSEventStream];
    
    NSArray *removedFiles = [self tidyShadowedFiles];
    
    if (removedFiles.count || modifiedPaths.count)
    {
        for (NSString *path in modifiedPaths)
            [self handleFileModificationAtPath:path];
        
        [self waitForOperationQueueToFinishWithSelector:@selector(operationsDidFinish)];
    }
}

/*!
 Handle a file modification. If it's a .j or xib/nib,
 perform the appropriate conversion. If it's .xcodecapp-ignore, it will
 update the list of ignored files.
 
 @param path The full resolved path of the modified file
 */
- (void)handleFileModificationAtPath:(NSString*)resolvedPath
{
    if (![self.fm fileExistsAtPath:resolvedPath])
        return;
    
    NSString *projectPath = [self.cappuccinoProject projectPathForSourcePath:resolvedPath];
    
    ProcessSourceOperation *op = [[ProcessSourceOperation alloc] initWithCappuccinoProject:self.cappuccinoProject
                                                                   taskManager:self.taskManager
                                                                  sourcePath:projectPath];
    [self.operationQueue addOperation:op];
}

- (void)handleRenamedDirectories:(NSArray *)directories
{
    // Make sure we don't get any more events while handling these events
    [self stopFSEventStream];
    
    DDLogVerbose(@"Renamed directories: %@", directories);
    
    [self tidyShadowedFiles];
    
    for (NSString *directory in directories)
    {
        // If it doesn't exist, it's the old name. Nothing to do.
        // If it does exist, populate the project with the directory.
        
        if ([self.fm fileExistsAtPath:directory])
        {
            // If the directory is within the project, we can populate it directly.
            // Otherwise we have to start at the top level and repopulate everything.
            if ([directory hasPrefix:self.cappuccinoProject.projectPath])
                [self populateXcodeProjectWithProjectRelativePath:[self.cappuccinoProject projectRelativePathForPath:directory]];
            else
            {
                [self populateXcodeProject];
                
                // Since everything has been repopulated, no point in continuing
                break;
            }
        }
    }
    
    [self waitForOperationQueueToFinishWithSelector:@selector(operationsDidFinish)];
}

- (NSArray *)tidyShadowedFiles
{
    NSArray *subpaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cappuccinoProject.supportPath error:nil];
    NSMutableArray *pathsToRemove = [NSMutableArray new];
    
    for (NSString *path in subpaths)
    {
        if ([CappuccinoUtils isHeaderFile:path] && ![path.lastPathComponent isEqualToString:@"xcc_general_include.h"])
        {
            NSString *sourcePath = [self.cappuccinoProject sourcePathForShadowPath:path];
            
            if (![self.fm fileExistsAtPath:sourcePath])
                [pathsToRemove addObject:sourcePath];
        }
    }
    
    [self removeReferencesToSourcePaths:pathsToRemove];
    
    if (pathsToRemove.count)
        self.pbxOperations[@"remove"] = pathsToRemove;
    
    return pathsToRemove;
}

/*!
 Clean up any shadow files and PBX entries related to given the Cappuccino source file path
 */
- (void)removeReferencesToSourcePaths:(NSArray *)sourcePaths
{
    for (NSString *sourcePath in sourcePaths)
    {
        NSString *shadowBasePath = [self.cappuccinoProject shadowBasePathForProjectSourcePath:sourcePath];
        NSString *shadowHeaderPath = [shadowBasePath stringByAppendingPathExtension:@"h"];
        NSString *shadowImplementationPath = [shadowBasePath stringByAppendingPathExtension:@"m"];
        
        [self.fm removeItemAtPath:shadowHeaderPath error:nil];
        [self.fm removeItemAtPath:shadowImplementationPath error:nil];
        
        //[self pruneProcessingErrorsForProjectPath:sourcePath];
    }
    
    if (sourcePaths.count)
        DDLogVerbose(@"Removed shadow references to: %@", sourcePaths);
}

- (void)updateUserDefaultsWithLastEventId
{
    UInt64 lastEventId = FSEventStreamGetLatestEventId(self.stream);
    
    // Just in case the stream callback was never called...
    if (lastEventId != 0)
        self.lastEventId = [NSNumber numberWithUnsignedLongLong:lastEventId];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.lastEventId forKey:kDefaultXCCLastEventId];
    [defaults synchronize];
}


#pragma mark - Processing methods

- (void)waitForOperationQueueToFinishWithSelector:(SEL)selector
{
    self.cappuccinoProject.isProcessingProject = YES;
    
    // Poll every half second to see if the queue has finished
    [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(didQueueTimerFinish:)
                                   userInfo:NSStringFromSelector(selector)
                                    repeats:YES];
}

- (void)didQueueTimerFinish:(NSTimer *)timer
{
    if (self.operationQueue.operationCount == 0)
    {
        SEL selector = NSSelectorFromString(timer.userInfo);
        
        [timer invalidate];
        
        // Can't use plain performSelect: here because ARC doesn't know what the return value is
        // because the selector is determined at runtime. So we use performSelectorOnMainThread:
        // which has no return value.
        [self performSelectorOnMainThread:selector withObject:nil waitUntilDone:NO];
        
        self.cappuccinoProject.isProcessingProject = NO;
    }
}

- (void)projectDidFinishLoading
{
    [self updatePbxFile];
    [self.cappuccinoProject fetchProjectSettings];
    
    self.cappuccinoProject.isLoadingProject = NO;
    self.cappuccinoProject.isProjectLoaded = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCProjectDidFinishLoadingNotification object:self];
    [[NSUserDefaults standardUserDefaults] setObject:self.cappuccinoProject.projectPath forKey:kDefaultXCCLastOpenedProjectPath];
    
    [CappuccinoUtils notifyUserWithTitle:@"Project loaded" message:self.cappuccinoProject.projectPath.lastPathComponent];
    
    DDLogVerbose(@"Project finished loading");
    
    [self startListenProject];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDefaultXCCAutoOpenXcodeProject])
        [self openXcodeProject:self];
}

- (void)operationsDidFinish
{
    [self updatePbxFile];
    
    // show errors
    
    // If the event stream was temporarily stopped, restart it
    [self startFSEventStream];
}

- (void)updatePbxFile
{
    // See pbxprojModifier.py for info on the arguments
    NSMutableArray *arguments = [[NSMutableArray alloc] initWithObjects:self.cappuccinoProject.pbxModifierScriptPath, @"update", self.cappuccinoProject.projectPath, nil];
    
    BOOL shouldLaunchTask = NO;
    
    for (NSString *action in self.pbxOperations)
    {
        NSArray *paths = self.pbxOperations[action];
        
        if (paths.count)
        {
            [arguments addObject:action];
            [arguments addObjectsFromArray:paths];
            
            shouldLaunchTask = YES;
        }
    }
    
    if (!shouldLaunchTask)
        return;

    // This task takes less than a second to execute, no need to put it a separate thread
    NSDictionary *taskResult = [self.taskManager runTaskWithCommand:@"python"
                                                 arguments:arguments
                                                returnType:kTaskReturnTypeStdError];
    
    NSInteger status = [taskResult[@"status"] intValue];
    NSString *response = taskResult[@"response"];
    
    DDLogVerbose(@"Updated Xcode project: [%ld, %@]", status, status ? response : @"");
}

#pragma mark - Action methods

- (IBAction)openXcodeProject:(id)aSender
{
    BOOL isDirectory, opened = YES;
    BOOL exists = [self.fm fileExistsAtPath:self.cappuccinoProject.xcodeProjectPath isDirectory:&isDirectory];
    
    if (exists && isDirectory)
    {
        DDLogVerbose(@"Opening Xcode project at: %@", self.cappuccinoProject.xcodeProjectPath);
        
        opened = [[NSWorkspace sharedWorkspace] openFile:self.cappuccinoProject.xcodeProjectPath];
    }
    
    if (!exists || !isDirectory || !opened)
    {
        NSString *text;
        
        if (!opened)
            text = @"The project exists, but failed to open.";
        else
            text = [NSString stringWithFormat:@"%@ %@.", self.cappuccinoProject.xcodeProjectPath, !exists ? @"does not exist" : @"is not an Xcode project"];
        
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        NSInteger response = NSRunAlertPanel(@"The project could not be opened.", @"%@\n\nWould you like to regenerate the project?", @"Yes", @"No", nil, text);
        
        if (response == NSAlertFirstButtonReturn)
            [self synchronizeProject:self];
    }
}

- (IBAction)synchronizeProject:(id)aSender
{
    [self resetProject];
    [self loadProject];
}

#pragma mark - cleaning methods

- (void)resetProjectForWatchedPath:(NSString *)path
{
    // If a watched path changes we don't have much choice but to reset the project.
    [self stopFSEventStream];
    
    if ([path isEqualToString:self.cappuccinoProject.projectPath])
    {
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        NSInteger response = NSRunAlertPanel(@"The project moved.", @"Your project directory has moved. Would you like to reload the project or quit XcodeCapp?", @"Reload", @"Quit", nil);
        
        BOOL shouldQuit = YES;
        
        if (response == NSAlertDefaultReturn)
        {
            char newPathBuf[MAXPATHLEN + 1];
            
            int result = fcntl(self.projectPathFileDescriptor, F_GETPATH, newPathBuf);
            
            if (result == 0)
            {
                self.cappuccinoProject.projectPath = [NSString stringWithUTF8String:newPathBuf];
                shouldQuit = NO;
            }
            else
                NSRunAlertPanel(@"The project can’t be located.", @"I’m sorry Dave, but I don’t know where the project went. I’m afraid I have to quit now.", @"OK, HAL", nil, nil);
        }
        
        if (shouldQuit)
        {
            [[NSApplication sharedApplication] terminate:self];
            return;
        }
    }
    
    [self synchronizeProject:self];
}

- (void)resetProject
{
    [self stopListenProject];
    [self.operationQueue cancelAllOperations];
    
    [CappuccinoUtils removeSupportFilesForCappuccinoProject:self.cappuccinoProject];
    [CappuccinoUtils removeAllCibsAtPath:[self.cappuccinoProject.projectPath stringByAppendingPathComponent:@"Resources"]];
    
    [self _init];
}

- (IBAction)save:(id)sender
{
    DDLogVerbose(@"Saving Cappuccino configuration project %@", self.cappuccinoProject.projectPath);
    
    [self.operationQueue cancelAllOperations];
    [self saveSettings];
    
    if (self.cappuccinoProject.isProjectLoaded)
    {
        self.taskManager = [self makeTaskManager];
        [self.cappuccinoProject updateIgnoredPath];
    }
    
    DDLogVerbose(@"Cappuccino configuration project %@ has been saved", self.cappuccinoProject.projectPath);
}

- (void)saveSettings
{
    NSMutableDictionary *currentSettings = [self.cappuccinoProject currentSettings];
    
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:currentSettings
                                                              format:NSPropertyListXMLFormat_v1_0
                                                    errorDescription:nil];
    
    [data writeToFile:self.cappuccinoProject.infoPlistPath atomically:YES];
    
    if ([self.cappuccinoProject.ignoredPathsContent length])
        [self.cappuccinoProject.ignoredPathsContent writeToFile:self.cappuccinoProject.xcodecappIgnorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    else if ([self.fm fileExistsAtPath:self.cappuccinoProject.xcodecappIgnorePath])
        [self.fm removeItemAtPath:self.cappuccinoProject.xcodecappIgnorePath error:nil];
}

#pragma mark - operation delegate and datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.currentOperations count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    OperationViewCell *cellView = [tableView makeViewWithIdentifier:@"OperationCell" owner:nil];
    [cellView setOperation:[self.currentOperations objectAtIndex:row]];
    
    [cellView.cancelButton setTarget:self];
    [cellView.cancelButton setAction:@selector(cancelOperation:)];
    
    return cellView;
}

- (void)cancelOperation:(id)sender
{
    ProcessSourceOperation *operation = [self.currentOperations objectAtIndex:[self.mainController.operationTableView rowForView:sender]];
    [operation cancel];
}

- (IBAction)cancelAllOperations:(id)aSender
{
    [self.currentOperations makeObjectsPerformSelector:@selector(cancel)];
}

@end
