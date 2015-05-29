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
#import "CappLintUtils.h"
#import "FindSourceFilesOperation.h"
#import "LogUtils.h"
#import "MainWindowController.h"
#import "OperationCellView.h"
#import "OperationError.h"
#import "OperationErrorCellView.h"
#import "OperationErrorHeaderCellView.h"
#import "ObjjUtils.h"
#import "ProcessSourceOperation.h"
#import "TaskManager.h"
#import "UserDefaults.h"
#import "XcodeProjectCloser.h"

enum XCCLineSpecifier {
    kLineSpecifierNone,
    kLineSpecifierColon,
    kLineSpecifierMinusL,
    kLineSpecifierPlus
};
typedef enum XCCLineSpecifier XCCLineSpecifier;

NSString * const XCCStartListeningProjectNotification = @"XCCStartListeningProject";
NSString * const XCCStopListeningProjectNotification = @"XCCStopListeningProject";

@interface CappuccinoProjectController ()

@property NSFileManager *fm;

// A queue for threaded operations to perform
@property NSOperationQueue *operationQueue;

// A queue for threaded operations to perform
@property NSMutableArray *operations;

@property FSEventStreamRef stream;

// The last FSEvent id we received. This is stored in the user prefs
// so we can get all changes since the last time XcodeCapp was launched.
@property NSNumber *lastEventId;

// We keep a file descriptor open for the project directory
// so we can locate it if it moves.
@property int projectPathFileDescriptor;

// Coalesces the modifications that have to be made to the Xcode project
// after changes are made to source files. Keys are the actions "add" or "remove",
// values are arrays of full paths to source files that need to be added or removed.
@property NSMutableDictionary *pbxOperations;

@property NSTimer *loadingTimer;

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
        
        [[NSUserDefaults standardUserDefaults] addObserver:self
                                                forKeyPath:kDefaultXCCMaxNumberOfOperations
                                                   options:NSKeyValueObservingOptionNew
                                                   context:NULL];
    }
    
    return self;
}

- (void)_init
{
    self.taskManager = nil;
    
    self.operations = [NSMutableArray new];
    
    self.operationQueue = [NSOperationQueue new];
    [self.operationQueue setMaxConcurrentOperationCount:[[[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCMaxNumberOfOperations] intValue]];
    
    [self _initPbxOperations];
    [self.cappuccinoProject _init];
    
    self.lastEventId = [[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCLastEventId];
    
    self.projectPathFileDescriptor = -1;
}

// Watch changes to the max number of operations in the preference
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
                        @"Some Executables are missing.",
                        @"Please make sure that each one of these executables:\n\n"
                        @"%@\n\n"
                        @"(or a symlink to it) is within one these directories:\n\n"
                        @"%@\n\n"
                        @"They do not all have to be in the same directory.",
                        @"OK",
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
    [self performSelectorInBackground:@selector(_loadProject) withObject:nil];
}

/*
 Load the project :
 
 - Init the controller
 - Init the global observer
 - Prepare the folder .XcodeSupport
 - Create the task manager
 - Find the source
 - Populate the xcodeproj
 
 If the project has been loaded, the method will only start to listen the project if needed
 
 */
- (void)_loadProject
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
    
    self.taskManager = [self makeTaskManager];
    
    if (!self.taskManager.isValid)
        return;
    
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

/*
 Check if the xCodeSupport is compatible with the current version of xCodeCapp
 
 @return YES if compatible
 */
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

/*
 Create the xCode project (create a file .pbxproj)
 */
- (void)createXcodeProject
{
    [self removeXcodeProject];
    
    [self.fm createDirectoryAtPath:self.cappuccinoProject.xcodeProjectPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *pbxPath = [self.cappuccinoProject.xcodeProjectPath stringByAppendingPathComponent:@"project.pbxproj"];
    
    [self.fm copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"project" ofType:@"pbxproj"] toPath:pbxPath error:nil];
    
    NSMutableString *content = [NSMutableString stringWithContentsOfFile:pbxPath encoding:NSUTF8StringEncoding error:nil];
    
    [content writeToFile:pbxPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    DDLogInfo(@"Xcode support project created at: %@", self.cappuccinoProject.xcodeProjectPath);
}

- (void)removeXcodeProject
{
    if ([self.fm fileExistsAtPath:self.cappuccinoProject.xcodeProjectPath])
        [self.fm removeItemAtPath:self.cappuccinoProject.xcodeProjectPath error:nil];
}

/*
 Create the folder .XcodeSupport
 */
- (void)createXcodeSupportDirectory
{
    [self removeXcodeSupportDirectory];
    
    [self.fm createDirectoryAtPath:self.cappuccinoProject.supportPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:[self.cappuccinoProject defaultSettings]
                                                              format:NSPropertyListXMLFormat_v1_0
                                                    errorDescription:nil];
    
    [data writeToFile:self.cappuccinoProject.infoPlistPath atomically:YES];
    
    DDLogInfo(@".XcodeSupport directory created at: %@", self.cappuccinoProject.supportPath);
}

- (void)removeXcodeSupportDirectory
{
    if ([self.fm fileExistsAtPath:self.cappuccinoProject.supportPath])
        [self.fm removeItemAtPath:self.cappuccinoProject.supportPath error:nil];
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

/* 
 Populate the array xCodeCappTargetedFiles based on the xcodecapp-ignore.
 Array which can be used to check the entire project
 */
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
    [self removeObservers];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self selector:@selector(addSourceToProjectPathMappingHandler:) name:XCCNeedSourceToProjectPathMappingNotification object:nil];
    
    [center addObserver:self selector:@selector(sourceConversionDidStartHandler:) name:XCCConversionDidStartNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionDidEndHandler:) name:XCCConversionDidEndNotification object:nil];
    
    [center addObserver:self selector:@selector(sourceConversionDidGenerateErrorHandler:) name:XCCConversionDidGenerateErrorNotification object:nil];
    
    
    [center addObserver:self selector:@selector(sourceConversionObjj2ObjcSkeletonDidStart:) name:XCCObjj2ObjcSkeletonDidStartNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionObjjDidStart:) name:XCCObjjDidStartNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionNib2CibDidStart:) name:XCCNib2CibDidStartNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionCappLintDidStart:) name:XCCCappLintDidStartNotification object:nil];
    
    [center addObserver:self selector:@selector(sourceConversionObjj2ObjcSkeletonDidGenerateErrorHandler:) name:XCCObjj2ObjcSkeletonDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionObjjDidGenerateErrorHandler:) name:XCCObjjDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionNib2CibDidGenerateErrorHandler:) name:XCCNib2CibDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(sourceConversionCappLintDidGenerateErrorHandler:) name:XCCCappLintDidGenerateErrorNotification object:nil];
}

- (void)removeObservers
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:self name:XCCNeedSourceToProjectPathMappingNotification object:nil];
    [center removeObserver:self name:XCCConversionDidStartNotification object:nil];
    [center removeObserver:self name:XCCConversionDidEndNotification object:nil];
    [center removeObserver:self name:XCCConversionDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCObjj2ObjcSkeletonDidStartNotification object:nil];
    [center removeObserver:self name:XCCObjjDidStartNotification object:nil];
    [center removeObserver:self name:XCCNib2CibDidStartNotification object:nil];
    [center removeObserver:self name:XCCCappLintDidStartNotification object:nil];
    [center removeObserver:self name:XCCObjj2ObjcSkeletonDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCObjjDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCNib2CibDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCCappLintDidGenerateErrorNotification object:nil];
}

- (BOOL)notificationBelongsToCurrentProject:(NSNotification *)note
{
    return note.userInfo[@"cappuccinoProject"] == self.cappuccinoProject;
}

- (void)addSourceToProjectPathMappingHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    self.cappuccinoProject.projectPathsForSourcePaths[note.userInfo[@"sourcePath"]] = note.userInfo[@"projectPath"];
}

- (void)sourceConversionDidStartHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self.operations performSelectorOnMainThread:@selector(addObject:) withObject:note.userInfo[@"operation"] waitUntilDone:YES];
    [self _reloadDataOperationsTableView];
}

- (void)sourceConversionObjj2ObjcSkeletonDidStart:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self performSelectorOnMainThread:@selector(pruneProcessingErrorsForSourcePath:) withObject:@{@"sourcePath" : note.userInfo[@"sourcePath"], @"type" : [NSNumber numberWithInt:XCCObjj2ObjcSkeletonOperationErrorType]} waitUntilDone:YES];
}

- (void)sourceConversionObjjDidStart:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self performSelectorOnMainThread:@selector(pruneProcessingErrorsForSourcePath:) withObject:@{@"sourcePath" : note.userInfo[@"sourcePath"], @"type" : [NSNumber numberWithInt:XCCObjjOperationErrorType]} waitUntilDone:YES];
}

- (void)sourceConversionNib2CibDidStart:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;

    [self performSelectorOnMainThread:@selector(pruneProcessingErrorsForSourcePath:) withObject:@{@"sourcePath" : note.userInfo[@"sourcePath"], @"type" : [NSNumber numberWithInt:XCCNib2CibOperationErrorType]} waitUntilDone:YES];
}

- (void)sourceConversionCappLintDidStart:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self performSelectorOnMainThread:@selector(pruneProcessingErrorsForSourcePath:) withObject:@{@"sourcePath" : note.userInfo[@"sourcePath"], @"type" : [NSNumber numberWithInt:XCCCappLintOperationErrorType]} waitUntilDone:YES];
}

- (void)sourceConversionDidEndHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    NSString *path = note.userInfo[@"sourcePath"];
    
    [self.operations performSelectorOnMainThread:@selector(removeObject:) withObject:note.userInfo[@"operation"] waitUntilDone:YES];
    [self _reloadDataOperationsTableView];
    
    if ([CappuccinoUtils isObjjFile:path])
        [self.pbxOperations[@"add"] addObject:path];
}

- (void)sourceConversionDidGenerateErrorHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self.operations performSelectorOnMainThread:@selector(removeObject:) withObject:note.userInfo[@"operation"] waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(sourceConversionDidGenerateError:) withObject:[OperationError defaultOperationErrorFromDictionary:note.userInfo] waitUntilDone:YES];
    [self _reloadDataOperationsTableView];
}

- (void)sourceConversionObjj2ObjcSkeletonDidGenerateErrorHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self.operations performSelectorOnMainThread:@selector(removeObject:) withObject:note.userInfo[@"operation"] waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(sourceConversionDidGenerateErrors:) withObject:[ObjjUtils operationErrorsFromDictionary:note.userInfo type:XCCObjj2ObjcSkeletonOperationErrorType] waitUntilDone:YES];
    [self _reloadDataOperationsTableView];
}

- (void)sourceConversionObjjDidGenerateErrorHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self.operations performSelectorOnMainThread:@selector(removeObject:) withObject:note.userInfo[@"operation"] waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(sourceConversionDidGenerateErrors:) withObject:[ObjjUtils operationErrorsFromDictionary:note.userInfo] waitUntilDone:YES];
    [self _reloadDataOperationsTableView];
}

- (void)sourceConversionNib2CibDidGenerateErrorHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self.operations performSelectorOnMainThread:@selector(removeObject:) withObject:note.userInfo[@"operation"] waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(sourceConversionDidGenerateError:) withObject:[OperationError nib2cibOperationErrorFromDictionary:note.userInfo] waitUntilDone:YES];
    [self _reloadDataOperationsTableView];
}

- (void)sourceConversionCappLintDidGenerateErrorHandler:(NSNotification *)note
{
    if (![self notificationBelongsToCurrentProject:note])
        return;
    
    [self.operations performSelectorOnMainThread:@selector(removeObject:) withObject:note.userInfo[@"operation"] waitUntilDone:YES];
    [self performSelectorOnMainThread:@selector(sourceConversionDidGenerateErrors:) withObject:[CappLintUtils operationErrorsFromDictionary:note.userInfo] waitUntilDone:YES];
    [self _reloadDataOperationsTableView];
}

- (void)sourceConversionDidGenerateErrors:(NSArray *)operationErrors
{
    for (OperationError *operationError in operationErrors)
        [self performSelectorOnMainThread:@selector(sourceConversionDidGenerateError:) withObject:operationError  waitUntilDone:YES];
}

- (void)sourceConversionDidGenerateError:(OperationError *)operationError
{
    DDLogVerbose(@"Cappuccino error : %@", operationError.message);
    
    if (![self.cappuccinoProject.errors objectForKey:operationError.fileName])
        [self.cappuccinoProject.errors setValue:[NSMutableArray new] forKey:operationError.fileName];
    
    [self.cappuccinoProject willChangeValueForKey:@"errors"];
    [[self.cappuccinoProject.errors objectForKey:operationError.fileName] addObject:operationError];
    [self.cappuccinoProject didChangeValueForKey:@"errors"];
    
    [self _reloadDataErrorsOutlineView];
}

- (void)pruneProcessingErrorsForSourcePath:(NSDictionary*)info
{
    NSString *sourcePath = info[@"sourcePath"];
    NSMutableArray *errorsToRemove = [NSMutableArray array];
    
    OperationError *defaultOperationError = [OperationError new];
    defaultOperationError.fileName = sourcePath;
    defaultOperationError.errorType = [info[@"errorType"] intValue];
    
    for (OperationError *operationError in [self.cappuccinoProject.errors objectForKey:sourcePath])
    {
        if ([operationError isEqualTo:defaultOperationError])
            [errorsToRemove addObject:operationError];
    }
    
    [self.cappuccinoProject willChangeValueForKey:@"errors"];
    [[self.cappuccinoProject.errors objectForKey:sourcePath] removeObjectsInArray:errorsToRemove];
    [self.cappuccinoProject didChangeValueForKey:@"errors"];
    
    if (![[self.cappuccinoProject.errors objectForKey:sourcePath] count])
        [self.cappuccinoProject.errors removeObjectForKey:sourcePath];
    
    [self _reloadDataErrorsOutlineView];
}

- (void)_reloadDataErrorsOutlineView
{
    [self.mainWindowController performSelectorOnMainThread:@selector(reloadErrors) withObject:nil waitUntilDone:NO];
}

/*
 Remove an operation and reload the tableView
 */
- (void)_reloadDataOperationsTableView
{
    [self.mainWindowController performSelectorOnMainThread:@selector(reloadOperations) withObject:nil waitUntilDone:NO];
}


#pragma mark - Events methods

- (void)startListenProject
{
    if (self.stream)
        return;
    
    DDLogInfo(@"Start to listen project: %@", self.cappuccinoProject.projectPath);
    
    [self stopListenProject];
    [self initObservers];
    
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCStartListeningProjectNotification object:self.cappuccinoProject];
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
    [self removeObservers];
    [_loadingTimer invalidate];
    [self.operationQueue cancelAllOperations];
    
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCStopListeningProjectNotification object:self.cappuccinoProject];
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
    _loadingTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                     target:self
                                   selector:@selector(didQueueTimerFinish:)
                                   userInfo:NSStringFromSelector(selector)
                                    repeats:YES];
    
    [[NSRunLoop currentRunLoop] run];
    [[NSRunLoop currentRunLoop] addTimer:_loadingTimer forMode:NSDefaultRunLoopMode];
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
        
        //[self performSelectorOnMainThread:selector withObject:nil waitUntilDone:NO];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:selector withObject:nil];
#pragma clang diagnostic pop
        
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
    
    // If the event stream was temporarily stopped, restart it
    [self startFSEventStream];
}

- (void)updatePbxFile
{
    [self _updatePbxFile];
}

- (void)_updatePbxFile
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

- (void)resetProjectForWatchedPath:(NSString *)path
{
    // If a watched path changes we don't have much choice but to reset the project.
    [self stopFSEventStream];
    
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
                self.cappuccinoProject = [[CappuccinoProject alloc] initWithPath:[NSString stringWithUTF8String:newPathBuf]];
                shouldUnlink = NO;
            }
            else
                NSRunAlertPanel(@"The project can’t be located.", @"I’m sorry Dave, but I don’t know where the project went. I’m afraid I have to quit now.", @"OK, HAL", nil, nil);
        }
        
        if (shouldUnlink)
        {
            [self.mainWindowController unlinkProject:self];
            return;
        }
    }
    
    [self synchronizeProject:self];
    [self.mainWindowController saveCurrentProjects];
}


#pragma mark - Settings methods

- (void)saveSettings
{
    NSMutableDictionary *currentSettings = [self.cappuccinoProject currentSettings];
    
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:currentSettings
                                                              format:NSPropertyListXMLFormat_v1_0
                                                    errorDescription:nil];
    
    [data writeToFile:self.cappuccinoProject.infoPlistPath atomically:YES];
    
    if ([self.cappuccinoProject.ignoredPathsContent length])
    {
        NSAttributedString *attributedString = (NSAttributedString*)self.cappuccinoProject.ignoredPathsContent;
        [[attributedString string] writeToFile:self.cappuccinoProject.xcodecappIgnorePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
    else if ([self.fm fileExistsAtPath:self.cappuccinoProject.xcodecappIgnorePath])
    {
        [self.fm removeItemAtPath:self.cappuccinoProject.xcodecappIgnorePath error:nil];
    }
}


#pragma mark - Synchronize method

/* Reset the project :
    
    - Stop to listen the project 
    - Cancel all current operations
    - Remove the support files
    - Remove all cibs
    - Initilize the controller
 */
- (void)resetProject
{
    [self stopListenProject];
    [self.operationQueue cancelAllOperations];
    
    [self removeSupportFiles];
    [self removeAllCibsAtPath:[self.cappuccinoProject.projectPath stringByAppendingPathComponent:@"Resources"]];
    
    if ([self.fm fileExistsAtPath:self.cappuccinoProject.xcodeProjectPath])
        [self.fm removeItemAtPath:self.cappuccinoProject.xcodeProjectPath error:nil];
    
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

- (void)removeSupportFiles
{
    NSFileManager *fm = [NSFileManager defaultManager];
    
    [XcodeProjectCloser closeXcodeProjectForProject:self.cappuccinoProject.projectPath];
    
    [fm removeItemAtPath:self.cappuccinoProject.xcodeProjectPath error:nil];
    [fm removeItemAtPath:self.cappuccinoProject.supportPath error:nil];
}


#pragma mark - tableView delegate and datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.operations count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    OperationCellView *cellView = [tableView makeViewWithIdentifier:@"OperationCell" owner:nil];
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
    return ![item isKindOfClass:[OperationError class]];
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
    if ([item isKindOfClass:[OperationError class]])
    {
        OperationErrorCellView *cellView = [outlineView makeViewWithIdentifier:@"OperationErrorCell" owner:nil];
        [cellView setOperationError:item];
        return cellView;
    }
    
    OperationErrorHeaderCellView *cellView = [outlineView makeViewWithIdentifier:@"OperationErrorHeaderCell" owner:nil];
    cellView.textField.stringValue = item;
    return cellView;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
    if ([item isKindOfClass:[OperationError class]])
        return 80.0;
    else
        return 20.0;
}


#pragma mark - IBActions methods

// Cancel all current operations
- (IBAction)cancelAllOperations:(id)aSender
{
    [self.operationQueue cancelAllOperations];
    [self.operations removeAllObjects];
    
    [self _reloadDataOperationsTableView];
}

// Cancel the operation linked to the sender
- (IBAction)cancelOperation:(id)sender
{
    ProcessSourceOperation *operation = [self.operationQueue.operations objectAtIndex:[self.mainWindowController.operationTableView rowForView:sender]];
    [operation cancel];
}

// Clean the errors tableView
- (IBAction)removeErrors:(id)aSender
{
    [self.cappuccinoProject willChangeValueForKey:@"errors"];
    [self.cappuccinoProject.errors removeAllObjects];
    [self.cappuccinoProject didChangeValueForKey:@"errors"];
    
    [self _reloadDataErrorsOutlineView];
}

// Save the configuration of Cappuccino
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

// Synchronize the project again and load it again
- (IBAction)synchronizeProject:(id)aSender
{
    [self resetProject];
    [self loadProject];
}

// Open the project on xCode
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

- (void)openObjjFile:(id)sender
{
    id item = [sender itemAtRow:[sender selectedRow]];
    
    NSString *path = item;
    NSInteger line = 1;
    
    if ([item isKindOfClass:[OperationError class]])
    {
        path = [(OperationError*)item fileName];
        line = [[(OperationError*)item lineNumber] intValue];
    }
    
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    
    NSString *app, *type;
    BOOL success = [workspace getInfoForFile:path application:&app type:&type];
    
    if (!success)
    {
        NSBeep();
        return;
    }
    
    NSBundle *bundle = [NSBundle bundleWithPath:app];
    NSString *identifier = bundle.bundleIdentifier;
    NSString *executablePath = nil;
    XCCLineSpecifier lineSpecifier = kLineSpecifierNone;
    
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
    
    [self.taskManager runTaskWithCommand:executablePath arguments:args returnType:kTaskReturnTypeNone];
}

@end
