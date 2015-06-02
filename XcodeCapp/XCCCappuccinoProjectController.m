//
//  CappuccinoProjectController.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/7/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCCappuccinoProjectController.h"

#import "XCCCappuccinoProject.h"
#import "CappuccinoUtils.h"
#import "CappLintUtils.h"
#import "XCCSourcesFinderOperation.h"
#import "LogUtils.h"
#import "XCCMainController.h"
#import "XCCOperationDataView.h"
#import "XCCOperationError.h"
#import "XCCOperationErrorDataView.h"
#import "XCCOperationErrorHeaderDataView.h"
#import "XCCPbxCreationOperation.h"
#import "ObjjUtils.h"
#import "XCCSourceProcessingOperation.h"
#import "XCCTaskLauncher.h"
#import "UserDefaults.h"
#import "XcodeProjectCloser.h"

@class XCCSourceProcessingOperation;

enum XCCLineSpecifier {
    kLineSpecifierNone,
    kLineSpecifierColon,
    kLineSpecifierMinusL,
    kLineSpecifierPlus
};
typedef enum XCCLineSpecifier XCCLineSpecifier;

NSString * const XCCStartListeningProjectNotification = @"XCCStartListeningProject";
NSString * const XCCStopListeningProjectNotification = @"XCCStopListeningProject";



@interface XCCCappuccinoProjectController ()

@property NSDate *lastReloadErrorsViewDate;
@property NSDate *lastReloadOperationsViewDate;
@property NSFileManager *fm;
@property NSMutableArray *operations;
@property FSEventStreamRef stream;
@property NSNumber *lastEventId;
@property int projectPathFileDescriptor;
@property NSMutableDictionary *pbxOperations;
@property NSTimer *loadingTimer;

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
    self = [super init];
    
    if (self)
    {
        self.fm = [NSFileManager defaultManager];
        self.cappuccinoProject = [[XCCCappuccinoProject alloc] initWithPath:aPath];
        self.mainWindowController = aController;
        
        [self _init];
        
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:kDefaultXCCMaxNumberOfOperations
                                                   options:NSKeyValueObservingOptionNew
                                                   context:NULL];
        [self _loadProject];
    }
    
    return self;
}

- (void)_init
{
    self.taskLauncher       = nil;
    self.operations         = [NSMutableArray new];
    self.operationQueue     = [[NSApp delegate] mainOperationQueue];
    self.operationsTotal    = 0;
    self.operationsComplete = 0;

    
    [self.operationQueue setMaxConcurrentOperationCount:[[[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCMaxNumberOfOperations] intValue]];
    
    [self _initPbxOperations];
    [self.cappuccinoProject _init];
    
    self.lastEventId = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCLastEventId];
    
    self.projectPathFileDescriptor = -1;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:kDefaultXCCMaxNumberOfOperations])
        [self.operationQueue setMaxConcurrentOperationCount:[[change objectForKey:NSKeyValueChangeNewKey] intValue]];
}

- (void)_initPbxOperations
{
    self.pbxOperations = [NSMutableDictionary new];
    
    self.pbxOperations[@"add"] = [NSMutableArray array];
    self.pbxOperations[@"remove"] = [NSMutableArray array];
}


#pragma mark - Task manager methods

- (void)initializeTaskLauncher
{
    NSArray *environmentPaths = [NSArray array];
    
    if ([self.cappuccinoProject.environmentsPaths count])
        environmentPaths = [self.cappuccinoProject.environmentsPaths valueForKeyPath:@"name"];
    
    self.taskLauncher = [[XCCTaskLauncher alloc] initWithEnvironementPaths:environmentPaths];
    
    if (!self.taskLauncher.isValid)
    {
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        
        NSRunAlertPanel(
                        @"Some Executables are missing.",
                        @"Please make sure that each one of these executables:\n\n"
                        @"%@\n\n"
                        @"(or a symlink to it) is within one these directories:\n\n"
                        @"%@\n\n"
                        @"You may also add custom binary path to the project configuration.",
                        @"OK",
                        nil,
                        nil,
                        [self.taskLauncher.executables componentsJoinedByString:@", "],
                        [self.taskLauncher.environmentPaths componentsJoinedByString:@"\n"]);
        
        self.cappuccinoProject.status = XCCCappuccinoProjectStatusInitialized;
    }
}



#pragma mark - Project State Management

- (void)_loadProject
{
    DDLogInfo(@"Loading project: %@", self.cappuccinoProject.projectPath);
    
    if (self.cappuccinoProject.status != XCCCappuccinoProjectStatusInitialized)
        return;
    
    [self _init];
    
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusLoading;
    
    [self _startListeningToNotifications];
    [self _prepareXcodeSupport];

    [self initializeTaskLauncher];

    if (!self.taskLauncher.isValid)
        return;
    
    [self _populateXcodeSupportDirectory];
    [self waitForOperationQueueToFinishWithSelector:@selector(_projectDidFinishLoading)];
}

- (void)_startListeningToProject
{
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
    [self _startFSEventStream];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCStartListeningProjectNotification object:self.cappuccinoProject];
    DDLogVerbose(@"FSEventStream started for paths: %@", pathsToWatch);
}

- (void)_stopListeningToProject
{
    if (self.cappuccinoProject.status == XCCCappuccinoProjectStatusStopped)
        return;
    
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusStopped;
    
    [self _stopListeningToNotifications];
    
    [_loadingTimer invalidate];
    [self _cancelAllProjectRelatedOperations];
    [self removeErrors:self];
    
    if (self.stream)
    {
        DDLogInfo(@"Stop listen project: %@", self.cappuccinoProject.projectPath);
        
        [self _updateUserDefaultsWithLastFSEventID];
        [self _stopFSEventStream];
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCStopListeningProjectNotification object:self.cappuccinoProject];
}


#pragma mark - XcodeSupport Management

- (BOOL)_prepareXcodeSupport
{
    // If either the project or the supmport directory are missing, recreate them both to ensure they are in sync
    BOOL projectExists, projectIsDirectory;
    projectExists = [self.fm fileExistsAtPath:self.cappuccinoProject.XcodeProjectPath isDirectory:&projectIsDirectory];
    
    BOOL supportExists, supportIsDirectory;
    supportExists = [self.fm fileExistsAtPath:self.cappuccinoProject.supportPath isDirectory:&supportIsDirectory];
    
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
    
    [self.fm createDirectoryAtPath:self.cappuccinoProject.XcodeProjectPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *pbxPath = [self.cappuccinoProject.XcodeProjectPath stringByAppendingPathComponent:@"project.pbxproj"];
    
    [self.fm copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"project" ofType:@"pbxproj"] toPath:pbxPath error:nil];
    
    NSMutableString *content = [NSMutableString stringWithContentsOfFile:pbxPath encoding:NSUTF8StringEncoding error:nil];
    
    [content writeToFile:pbxPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    DDLogInfo(@"Xcode support project created at: %@", self.cappuccinoProject.XcodeProjectPath);
}

- (void)_removeXcodeProject
{
    if ([self.fm fileExistsAtPath:self.cappuccinoProject.XcodeProjectPath])
        [self.fm removeItemAtPath:self.cappuccinoProject.XcodeProjectPath error:nil];
}

- (void)_createXcodeSupportDirectory
{
    [self _removeXcodeSupportDirectory];
    
    [self.fm createDirectoryAtPath:self.cappuccinoProject.supportPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:self.cappuccinoProject.settings
                                                              format:NSPropertyListXMLFormat_v1_0
                                                    errorDescription:nil];
    
    [data writeToFile:self.cappuccinoProject.infoPlistPath atomically:YES];
    
    DDLogInfo(@".XcodeSupport directory created at: %@", self.cappuccinoProject.supportPath);
}

- (void)_removeXcodeSupportDirectory
{
    [XcodeProjectCloser closeXcodeProjectForProject:self.cappuccinoProject.projectPath];
    
    if ([self.fm fileExistsAtPath:self.cappuccinoProject.supportPath])
        [self.fm removeItemAtPath:self.cappuccinoProject.supportPath error:nil];
}

- (void)_populateXcodeSupportDirectory
{
    // Populate with all non-framework code
    [self _populateXcodeSupportDirectoryWithProjectRelativePath:@""];
    
    // Populate with any user source debug frameworks
    [self _populateXcodeSupportDirectoryWithProjectRelativePath:@"Frameworks/Debug"];
    
    // Populate with any source frameworks
    [self _populateXcodeSupportDirectoryWithProjectRelativePath:@"Frameworks/Source"];
    
    // Populate resources
    [self _populateXcodeSupportDirectoryWithProjectRelativePath:@"Resources"];
}

- (void)_populateXcodeSupportDirectoryWithProjectRelativePath:(NSString *)path
{
    XCCSourcesFinderOperation *op = [[XCCSourcesFinderOperation alloc] initWithCappuccinoProject:self.cappuccinoProject taskLauncher:self.taskLauncher sourcePath:path];
    [self.operationQueue addOperation:op];
}


#pragma mark - Notifications Management

- (void)_startListeningToNotifications
{
    [self _stopListeningToNotifications];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self selector:@selector(_didReceiveCappLintDidGenerateErrorNotification:) name:XCCCappLintDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveCappLintDidStartNotification:) name:XCCCappLintDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveConversionDidEndNotification:) name:XCCConversionDidEndNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveConversionDidGenerateErrorNotification:) name:XCCConversionDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveConversionDidStartNotification:) name:XCCConversionDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveNeedSourceToProjectPathMappingNotification:) name:XCCNeedSourceToProjectPathMappingNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveNib2CibDidGenerateErrorNotification:) name:XCCNib2CibDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveNib2CibDidStartNotifcation:) name:XCCNib2CibDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveObjj2ObjcSeleketonDidGenerateErrorNotification:) name:XCCObjj2ObjcSkeletonDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveObjj2ObjcSkeletonDidStartNotification:) name:XCCObjj2ObjcSkeletonDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveObjjDidGenerateErrorNotification:) name:XCCObjjDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveObjjDidStartNotification:) name:XCCObjjDidStartNotification object:nil];
}

- (void)_stopListeningToNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center removeObserver:self name:XCCCappLintDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCCappLintDidStartNotification object:nil];
    [center removeObserver:self name:XCCConversionDidEndNotification object:nil];
    [center removeObserver:self name:XCCConversionDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCConversionDidStartNotification object:nil];
    [center removeObserver:self name:XCCNeedSourceToProjectPathMappingNotification object:nil];
    [center removeObserver:self name:XCCNib2CibDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCNib2CibDidStartNotification object:nil];
    [center removeObserver:self name:XCCObjj2ObjcSkeletonDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCObjj2ObjcSkeletonDidStartNotification object:nil];
    [center removeObserver:self name:XCCObjjDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCObjjDidStartNotification object:nil];
}

- (BOOL)_doesNotificationBelongToCurrentProject:(NSNotification *)note
{
    return note.userInfo[@"cappuccinoProject"] == self.cappuccinoProject;
}

- (void)_didReceiveNeedSourceToProjectPathMappingNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    self.cappuccinoProject.projectPathsForSourcePaths[note.userInfo[@"sourcePath"]] = note.userInfo[@"projectPath"];
}

- (void)_didReceiveConversionDidStartNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self _addOperation:note.userInfo[@"operation"]];
}

- (void)_didReceiveObjj2ObjcSkeletonDidStartNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProject removeOperationErrorsRelatedToSourcePath:note.userInfo[@"sourcePath"] errorType:XCCObjj2ObjcSkeletonOperationErrorType];
}

- (void)_didReceiveObjjDidStartNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProject removeOperationErrorsRelatedToSourcePath:note.userInfo[@"sourcePath"] errorType:XCCObjjOperationErrorType];
}

- (void)_didReceiveNib2CibDidStartNotifcation:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;

    [self.cappuccinoProject removeOperationErrorsRelatedToSourcePath:note.userInfo[@"sourcePath"] errorType:XCCNib2CibOperationErrorType];
}

- (void)_didReceiveCappLintDidStartNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProject removeOperationErrorsRelatedToSourcePath:note.userInfo[@"sourcePath"] errorType:XCCCappLintOperationErrorType];
}

- (void)_didReceiveConversionDidEndNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self _removeOperation:note.userInfo[@"operation"]];
    
    NSString *path = note.userInfo[@"sourcePath"];
    if ([CappuccinoUtils isObjjFile:path])
        [self.pbxOperations[@"add"] addObject:path];
    
    [self _reloadDataErrorsOutlineView];
}

- (void)_didReceiveConversionDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProject addOperationError:[XCCOperationError defaultOperationErrorFromDictionary:note.userInfo]];
}

- (void)_didReceiveObjj2ObjcSeleketonDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    for (XCCOperationError *operationError in [ObjjUtils operationErrorsFromDictionary:note.userInfo type:XCCObjj2ObjcSkeletonOperationErrorType])
        [self.cappuccinoProject addOperationError:operationError];
}

- (void)_didReceiveObjjDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;

    for (XCCOperationError *operationError in [ObjjUtils operationErrorsFromDictionary:note.userInfo])
        [self.cappuccinoProject addOperationError:operationError];
}

- (void)_didReceiveNib2CibDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;

    [self.cappuccinoProject addOperationError:[XCCOperationError nib2cibOperationErrorFromDictionary:note.userInfo]];
}

- (void)_didReceiveCappLintDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;

    for (XCCOperationError *operationError in [CappLintUtils operationErrorsFromDictionary:note.userInfo])
        [self.cappuccinoProject addOperationError:operationError];
}


#pragma mark - Operation Management

- (void)_addOperation:(NSOperation*)anOperation
{
    [self.operations addObject:anOperation];
    [self _reloadDataOperationsTableView];
    
    self.operationsTotal++;
    [self _updateOperationsProgress];
}

- (void)_removeOperation:(NSOperation*)anOperation
{
    [self.operations removeObject:anOperation];
    [self _reloadDataOperationsTableView];
    
    self.operationsComplete++;
    [self _updateOperationsProgress];
}

- (void)_updateOperationsProgress
{
    if (self.operationsTotal == 0)
        [self _resetOperationCounters];
    
    self.operationsProgress = (float)self.operationsComplete / (float)self.operationsTotal;
    
    if (self.operationsProgress == 1.0)
        [self _resetOperationCounters];
}

- (void)_resetOperationCounters
{
    self.operationsProgress = 1.0;
    self.operationsComplete = 0;
    self.operationsTotal    = 0;
}


#pragma mark - Application Lifecycle

- (void)applicationIsClosing
{
    [self _stopListeningToProject];
    [self.cappuccinoProject saveSettings];
}

- (void)cleanUpBeforeDeletion
{
    [self _stopListeningToNotifications];
    [self _stopListeningToProject];
    [self _removeXcodeProject];
    [self _removeXcodeSupportDirectory];
}


#pragma mark - FS Events Management


- (void)_startFSEventStream
{
    FSEventStreamStart(self.stream);
}

- (void)_stopFSEventStream
{
    FSEventStreamStop(self.stream);
}

- (void)_handleFSEventsWithPaths:(NSArray *)paths flags:(const FSEventStreamEventFlags[])eventFlags ids:(const FSEventStreamEventId[])eventIds
{
    DDLogVerbose(@"FSEvents: %ld path(s)", paths.count);
    [self _initPbxOperations];
    
    NSMutableArray *modifiedPaths       = [NSMutableArray new];
    NSMutableArray *renamedDirectories  = [NSMutableArray new];
    
    BOOL needUpdate = NO;
    
    for (size_t i = 0; i < paths.count; ++i)
    {
        FSEventStreamEventFlags flags       = eventFlags[i];
        NSString                *path       = [paths[i] stringByStandardizingPath];
        BOOL                    rootChanged = (flags & kFSEventStreamEventFlagRootChanged) != 0;
        
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

        BOOL inodeMetaModified  = (flags & kFSEventStreamEventFlagItemInodeMetaMod) != 0;
        BOOL isFile             = (flags & kFSEventStreamEventFlagItemIsFile)       != 0;
        BOOL isSymlink          = (flags & kFSEventStreamEventFlagItemIsSymlink)    != 0;
        BOOL isDir              = (flags & kFSEventStreamEventFlagItemIsDir)        != 0;
        BOOL renamed            = (flags & kFSEventStreamEventFlagItemRenamed)      != 0;
        BOOL modified           = (flags & kFSEventStreamEventFlagItemModified)     != 0;
        BOOL created            = (flags & kFSEventStreamEventFlagItemCreated)      != 0;
        BOOL removed            = (flags & kFSEventStreamEventFlagItemRemoved)      != 0;
        
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
        else if ((isFile || isSymlink) &&
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
        else if ((isFile || isSymlink) && (renamed || removed) && !(modified || created) && [CappuccinoUtils isCibFile:path])
        {
            DDLogVerbose(@"FSEvent accepted");
            
            // If a cib is deleted, mark its xib as needing update so the cib is regenerated
            NSString *xibPath = [path.stringByDeletingPathExtension stringByAppendingPathExtension:@"xib"];
            
            if ([self.fm fileExistsAtPath:xibPath])
            {
                [modifiedPaths addObject:xibPath];
                needUpdate = YES;
            }
        }
        else if ((isFile || isSymlink) &&
                 (created || modified || renamed || removed || inodeMetaModified) &&
                 [CappuccinoUtils isXCCIgnoreFile:path cappuccinoProject:self.cappuccinoProject])
        {
            DDLogVerbose(@"FSEvent accepted");
            
            [self.cappuccinoProject reloadXcodeCappIgnoreFile];
        }
    }
    
    // If directories were renamed, we take the easy way out and reset the project
    if (renamedDirectories.count)
        [self _handleProjectDirectoryRenamingAtPaths:renamedDirectories];
    else if (needUpdate)
        [self _updateXcodeSupportFilesWithModifiedPaths:modifiedPaths];
}

- (void)_updateXcodeSupportFilesWithModifiedPaths:(NSArray *)modifiedPaths
{
    // Make sure we don't get any more events while handling these events
    [self _stopFSEventStream];
    
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusProcessing;
    
    DDLogVerbose(@"Modified files: %@", modifiedPaths);
    
    [self _removeXcodeSupportOrphanFiles];
    
    for (NSString *path in modifiedPaths)
    {
        if (![self.fm fileExistsAtPath:path])
            continue;
        
        XCCSourceProcessingOperation *op = [[XCCSourceProcessingOperation alloc] initWithCappuccinoProject:self.cappuccinoProject
                                                                                   taskLauncher:self.taskLauncher
                                                                                    sourcePath:[self.cappuccinoProject projectPathForSourcePath:path]];

        [self.operationQueue addOperation:op];
    }
    
    [self waitForOperationQueueToFinishWithSelector:@selector(_operationsDidFinish)];
}

- (void)_handleProjectDirectoryRenamingAtPaths:(NSArray *)directories
{
    // Make sure we don't get any more events while handling these events
    [self _stopFSEventStream];
    
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusProcessing;
    
    DDLogVerbose(@"Renamed directories: %@", directories);
    
    [self _removeXcodeSupportOrphanFiles];
    
    for (NSString *directory in directories)
    {
        // If it doesn't exist, it's the old name. Nothing to do.
        // If it does exist, populate the project with the directory.
        
        if ([self.fm fileExistsAtPath:directory])
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
    
    [self waitForOperationQueueToFinishWithSelector:@selector(_operationsDidFinish)];
}

- (void)_removeXcodeSupportOrphanFiles
{
    NSArray         *subpaths       = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.cappuccinoProject.supportPath error:nil];
    NSMutableArray  *orphanFiles    = [NSMutableArray new];
    
    for (NSString *path in subpaths)
    {
        if ([CappuccinoUtils isHeaderFile:path] && ![path.lastPathComponent isEqualToString:@"xcc_general_include.h"])
        {
            NSString *sourcePath = [self.cappuccinoProject sourcePathForShadowPath:path];
            
            if (![self.fm fileExistsAtPath:sourcePath])
                [orphanFiles addObject:sourcePath];
        }
    }

    [self _removeXcodeSupportFilesForProjectSourcesAtPaths:orphanFiles];
}

- (void)_removeXcodeSupportFilesForProjectSourcesAtPaths:(NSArray *)sourcePaths
{
    for (NSString *sourcePath in sourcePaths)
    {
        NSString *shadowBasePath            = [self.cappuccinoProject shadowBasePathForProjectSourcePath:sourcePath];
        NSString *shadowHeaderPath          = [shadowBasePath stringByAppendingPathExtension:@"h"];
        NSString *shadowImplementationPath  = [shadowBasePath stringByAppendingPathExtension:@"m"];
        
        [self.fm removeItemAtPath:shadowHeaderPath error:nil];
        [self.fm removeItemAtPath:shadowImplementationPath error:nil];
        
        [self.cappuccinoProject removeOperationErrorsRelatedToSourcePath:sourcePath errorType:XCCDefaultOperationErrorType];
    }
    
    [self _reloadDataErrorsOutlineView];
    
    if (sourcePaths.count)
    {
        self.pbxOperations[@"remove"] = sourcePaths;
        DDLogVerbose(@"Removed shadow references to: %@", sourcePaths);
    }

}

- (void)_updateUserDefaultsWithLastFSEventID
{
    UInt64 lastEventId = FSEventStreamGetLatestEventId(self.stream);
    
    // Just in case the stream callback was never called...
    if (lastEventId != 0)
        self.lastEventId = [NSNumber numberWithUnsignedLongLong:lastEventId];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:self.lastEventId forKey:kDefaultXCCLastEventId];
    [defaults synchronize];
}

- (void)_operationsDidFinish
{
    [self _updatePbxFile];
    
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusListening;
    
    // If the event stream was temporarily stopped, restart it
    [self _startFSEventStream];
}



#pragma mark - Processing methods

- (void)waitForOperationQueueToFinishWithSelector:(SEL)selector
{
    [self _scheduleLoadingTimerWithSelector:selector];
}

- (void)_scheduleLoadingTimerWithSelector:(SEL)selector
{
    _loadingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                     target:self
                                                   selector:@selector(_didLoadingTimerFinish:)
                                                   userInfo:@{@"selector" : NSStringFromSelector(selector)}
                                                    repeats:NO];
  
}

- (void)_didLoadingTimerFinish:(NSTimer *)timer
{
    SEL selector = NSSelectorFromString(timer.userInfo[@"selector"]);
    
    if ([[self _projectRelatedOperations] count] > 0)
    {
        [self _scheduleLoadingTimerWithSelector:selector];
        return;
    }

    
    // Can't use plain performSelect: here because ARC doesn't know what the return value is
    // because the selector is determined at runtime. So we use performSelectorOnMainThread:
    // which has no return value.
    
    //[self performSelectorOnMainThread:selector withObject:nil waitUntilDone:NO];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [self performSelector:selector withObject:nil];
#pragma clang diagnostic pop
}

- (void)_projectDidFinishLoading
{
    [self _updatePbxFile];
    
    self.cappuccinoProject.status = XCCCappuccinoProjectStatusStopped;
    
    [CappuccinoUtils notifyUserWithTitle:@"Project loaded" message:self.cappuccinoProject.projectPath.lastPathComponent];
    
    DDLogVerbose(@"Project finished loading");
    
    if (self.cappuccinoProject.autoStartListening)
        [self _startListeningToProject];
}

- (void)_updatePbxFile
{
    XCCPbxCreationOperation *pbxOperation = [[XCCPbxCreationOperation alloc] initWithCappuccinoProject:self.cappuccinoProject taskLauncher:self.taskLauncher pbxOperations:self.pbxOperations];
    
    [self.operationQueue addOperation:pbxOperation];
}

- (void)resetProjectForWatchedPath:(NSString *)path
{
    // If a watched path changes we don't have much choice but to reset the project.
    [self _stopFSEventStream];
    
    if ([path isEqualToString:self.cappuccinoProject.projectPath])
    {
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        NSInteger response = NSRunAlertPanel(@"The project moved.", @"Your project directory has moved. Would you like to reload the project or unlink it from XcodeCapp?", @"Reload", @"Unlink", nil);
        
        BOOL shouldUnlink = YES;
        
        if (response == NSAlertDefaultReturn)
        {
            char newPathBuf[MAXPATHLEN + 1];
            
            int result = fcntl(self.projectPathFileDescriptor, F_GETPATH, newPathBuf);
            
            if (result == 0)
            {
                self.cappuccinoProject = [[XCCCappuccinoProject alloc] initWithPath:[NSString stringWithUTF8String:newPathBuf]];
                shouldUnlink = NO;
            }
            else
                NSRunAlertPanel(@"The project can’t be located.", @"I’m sorry Dave, but I don’t know where the project went. I’m afraid I have to quit now.", @"OK, HAL", nil, nil);
        }
        
        if (shouldUnlink)
        {
            [self.mainWindowController removeCappuccinoProject:self];
            return;
        }
    }
    
    [self resetProject:self];
    [self.mainWindowController _saveManagedProjectsToUserDefaults];
}


#pragma mark - Synchronize method

- (void)reinitializeProjectFromSettings
{
    DDLogVerbose(@"Saving Cappuccino configuration project %@", self.cappuccinoProject.projectPath);
    
    [self _cancelAllProjectRelatedOperations];
    [self.cappuccinoProject saveSettings];
    
    [self _stopListeningToProject];
    [self initializeTaskLauncher];
    [self _startListeningToProject];
    
    DDLogVerbose(@"Cappuccino configuration project %@ has been saved", self.cappuccinoProject.projectPath);
}

- (void)_resetProject
{
    [self _stopListeningToProject];
    [self _cancelAllProjectRelatedOperations];
    
    [self _removeXcodeSupportDirectory];
    [self removeAllCibsAtPath:[self.cappuccinoProject.projectPath stringByAppendingPathComponent:@"Resources"]];
    
    if ([self.fm fileExistsAtPath:self.cappuccinoProject.XcodeProjectPath])
        [self.fm removeItemAtPath:self.cappuccinoProject.XcodeProjectPath error:nil];
    
    [self _init];
}

- (void)removeAllCibsAtPath:(NSString *)path
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSArray *paths = [fm contentsOfDirectoryAtPath:path error:nil];
    
    for (NSString *filePath in paths)
    {
        if ([CappuccinoUtils isCibFile:filePath])
            [fm removeItemAtPath:[path stringByAppendingPathComponent:filePath] error:nil];
    }
}

- (void)_cancelAllProjectRelatedOperations
{
    [[self _projectRelatedOperations] makeObjectsPerformSelector:@selector(cancel)];
}

- (NSArray*)_projectRelatedOperations
{
    return [self.operationQueue.operations filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"cappuccinoProject.projectPath == %@", self.cappuccinoProject.projectPath]];
}


#pragma mark - Actions

- (IBAction)cancelAllOperations:(id)aSender
{
    [self _cancelAllProjectRelatedOperations];
    [self.operations removeAllObjects];
    
    [self _reloadDataOperationsTableView];
}

- (IBAction)cancelOperation:(id)sender
{
    XCCSourceProcessingOperation *operation = [[self _projectRelatedOperations] objectAtIndex:[self.mainWindowController.operationTableView rowForView:sender]];
    [operation cancel];
}

- (IBAction)removeErrors:(id)aSender
{
    [self.cappuccinoProject removeAllOperationErrors];
    [self _reloadDataErrorsOutlineView];
}

- (IBAction)resetProject:(id)aSender
{
    [self _resetProject];
    [self _loadProject];
}

- (IBAction)openXcodeProject:(id)aSender
{
    BOOL isDirectory, opened = YES;
    BOOL exists = [self.fm fileExistsAtPath:self.cappuccinoProject.XcodeProjectPath isDirectory:&isDirectory];
    
    if (exists && isDirectory)
    {
        DDLogVerbose(@"Opening Xcode project at: %@", self.cappuccinoProject.XcodeProjectPath);
        
        opened = [[NSWorkspace sharedWorkspace] openFile:self.cappuccinoProject.XcodeProjectPath];
    }
    
    if (!exists || !isDirectory || !opened)
    {
        NSString *text;
        
        if (!opened)
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
    NSArray     *contents = [self.fm contentsOfDirectoryAtPath:self.cappuccinoProject.projectPath error:nil];
    NSString *  firstObjjFile;
    
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
    
    [self _launchEditorForPath:self.cappuccinoProject.projectPath line:0 applicationIdentifier:applicationIdentifier];
}

- (void)openObjjFile:(id)sender
{
    id item = [sender itemAtRow:[sender selectedRow]];
    
    NSString *path = item;
    NSInteger line = 1;
    
    if ([item isKindOfClass:[XCCOperationError class]])
    {
        path = [(XCCOperationError*)item fileName];
        line = [[(XCCOperationError*)item lineNumber] intValue];
    }

    [self _launchEditorForPath:path line:line applicationIdentifier:[self _managingApplicationIdenfierForFilePath:path]];
}

- (NSString *)_managingApplicationIdenfierForFilePath:(NSString *)filePath
{
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSString *app, *type;
    
    BOOL success = [workspace getInfoForFile:filePath application:&app type:&type];

    return success ? app : nil;
}

- (void)_launchEditorForPath:(NSString*)path line:(NSInteger)line applicationIdentifier:(NSString *)applicationIdentifier
{
    if (!applicationIdentifier)
        return;
    
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
        if ([self.fm isExecutableFileAtPath:@"/usr/bin/aquamacs"])
            executablePath = @"/usr/bin/aquamacs";
        else if ([self.fm isExecutableFileAtPath:@"/usr/local/bin/aquamacs"])
            executablePath = @"/usr/local/bin/aquamacs";
    }
    else if ([identifier isEqualToString:@"com.apple.dt.Xcode"])
    {
        executablePath = [[bundle bundlePath] stringByAppendingPathComponent:@"Contents/Developer/usr/bin/xed"];
    }
    
    if (!executablePath || ![self.fm isExecutableFileAtPath:executablePath])
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
    
    [self.taskLauncher runTaskWithCommand:executablePath arguments:args returnType:kTaskReturnTypeNone];
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


#pragma mark - Errors and Operation Reloading

- (void)_reloadDataErrorsOutlineView
{
    //    if (self.lastReloadErrorsViewDate && ABS([self.lastReloadErrorsViewDate timeIntervalSinceNow]) < 0.5)
    //        return;
    
    [self.mainWindowController reloadErrorsListForCurrentCappuccinoProject];
    
    self.lastReloadErrorsViewDate = [NSDate date];
}

- (void)_reloadDataOperationsTableView
{
    //    if (self.lastReloadOperationsViewDate && ABS([self.lastReloadOperationsViewDate timeIntervalSinceNow]) < 0.5)
    //        return;
    
    [self.mainWindowController reloadOperationsListForCurrentCappuccinoProject];
    
    self.lastReloadOperationsViewDate = [NSDate date];
}

- (IBAction)openProjectInTerminal:(id)sender;
{
    NSString *s = [NSString stringWithFormat:@"tell application \"Terminal\"\n do script \"cd %@\" \n activate\n end tell", self.cappuccinoProject.projectPath];
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:s];
    [script executeAndReturnError:nil];
}

#pragma mark - tableView delegate and datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.operations count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    XCCOperationDataView *cellView = [tableView makeViewWithIdentifier:@"OperationCell" owner:nil];
    [cellView setOperation:[self.operations objectAtIndex:row]];
    
    [cellView.cancelButton setTarget:self];
    [cellView.cancelButton setAction:@selector(cancelOperation:)];
    
    return cellView;
}


#pragma mark - outlineView data source and delegate

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (!item)
        return [[self.cappuccinoProject.errors allKeys] count];
    
    return [[self.cappuccinoProject.errors objectForKey:item] count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return ![item isKindOfClass:[XCCOperationError class]];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (!item)
        return [[self.cappuccinoProject.errors allKeys] objectAtIndex:index];
    
    return [[self.cappuccinoProject.errors objectForKey:item] objectAtIndex:index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    return item;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([item isKindOfClass:[XCCOperationError class]])
    {
        XCCOperationErrorDataView *cellView = [outlineView makeViewWithIdentifier:@"OperationErrorCell" owner:nil];
        [cellView setOperationError:item];
        return cellView;
    }
    
    XCCOperationErrorHeaderDataView *cellView = [outlineView makeViewWithIdentifier:@"OperationErrorHeaderCell" owner:nil];
    cellView.textField.stringValue = item;
    return cellView;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(XCCOperationError *)item
{
    if ([item isKindOfClass:[XCCOperationError class]])
    {
        CGRect frame = [item.message boundingRectWithSize:CGSizeMake([outlineView frame].size.width, CGFLOAT_MAX)
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                               attributes:@{ NSFontAttributeName:[NSFont fontWithName:@"Menlo" size:11] }];
        
        return frame.size.height + 38.0;
    }
    
    else
        return 20.0;
}

@end


