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
#import "ProcessSourceOperation.h"
#import "TaskManager.h"
#import "UserDefaults.h"
#import "XcodeProjectCloser.h"

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_6
#   define kFSEventStreamCreateFlagFileEvents       0x00000010
#   define kFSEventStreamEventFlagItemIsFile        0x00010000
#   define kFSEventStreamEventFlagItemRemoved       0x00000200
#   define kFSEventStreamEventFlagItemCreated       0x00000200
#   define kFSEventStreamEventFlagItemModified      0x00001000
#   define kFSEventStreamEventFlagItemInodeMetaMod  0x00000400
#   define kFSEventStreamEventFlagItemRenamed       0x00000800
#   define kFSEventStreamEventFlagItemFinderInfoMod 0x00002000
#   define kFSEventStreamEventFlagItemChangeOwner   0x00004000
#   define kFSEventStreamEventFlagItemXattrMod      0x00008000
#endif

@interface CappuccinoProjectController ()

@property NSFileManager *fm;

// A queue for threaded operations to perform
@property NSOperationQueue *operationQueue;

@end

@implementation CappuccinoProjectController

#pragma mark - Init methods

- (id)initWithPath:(NSString*)aPath
{
    self = [super init];
    
    if (self)
    {
        self.fm = [NSFileManager defaultManager];
        self.cappuccinoProject = [[CappuccinoProject alloc] initWithPath:aPath];
        
        self.pbxModifierScriptPath = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"pbxprojModifier.py"];
        
        self.parserPath = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"parser.j"];
        
        [self _init];
    }
    
    return self;
}

- (void)_init
{
    self.taskManager = nil;
    
    self.operationQueue = [NSOperationQueue new];
    
    self.errorList = [NSMutableArray array];
    self.warningList = [NSMutableArray array];
    self.currentOperations = [NSMutableArray array];
    
    self.isLoadingProject = NO;
    self.isListeningProject = NO;
    self.isProcessingProject = NO;
}

- (TaskManager*)makeTaskManager
{
    TaskManager *taskManager = [[TaskManager alloc] initWithEnvironementPaths:self.cappuccinoProject.environementsPaths];
    
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
    self.isLoadingProject = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCProjectDidStartLoadingNotification object:self];
    
    [self initObservers];
    [self.cappuccinoProject initIgnoredPaths];
    [self prepareXcodeSupport];
    [self initTaskManager];
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
    FindSourceFilesOperation *op = [[FindSourceFilesOperation alloc] initWithCappuccinoProject:self.cappuccinoProject controller:self path:path];
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
}

- (BOOL)notificationBelongsToCurrentProject:(NSNotification *)note
{
    return note.userInfo[@"controller"] == self;
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
    
    [self.currentOperations addObject:note.object];
    
    if ([CappuccinoUtils isObjjFile:path])
    {
        //        NSMutableArray *addPaths = [self.pbxOperations[@"add"] mutableCopy];
        //
        //        if (!addPaths)
        //            self.pbxOperations[@"add"] = @[path];
        //        else
        //        {
        //            [addPaths addObject:path];
        //            self.pbxOperations[@"add"] = addPaths;
        //        }
    }
    
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


#pragma mark - task managers methods

- (void)initTaskManager
{
    NSArray *paths = [self.cappuccinoProject settingValueForKey:XCCCappuccinoProjectBinPaths];
    
    if ([paths count])
        self.cappuccinoProject.environementsPaths = [paths copy];
    else
        self.cappuccinoProject.environementsPaths = [CappuccinoProject defaultEnvironmentPaths];
    
    self.taskManager = [self makeTaskManager];
}


#pragma mark - Events methods

- (void)startListenProject
{
    DDLogInfo(@"Start listen project: %@", self.cappuccinoProject.projectPath);
    self.isListeningProject = YES;
}

- (void)stopListenProject
{
    DDLogInfo(@"Stop listen project: %@", self.cappuccinoProject.projectPath);
    self.isListeningProject = NO;
}

#pragma mark - Processing methods

- (void)waitForOperationQueueToFinishWithSelector:(SEL)selector
{
    self.isProcessingProject = YES;
    
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
    }
}

- (void)projectDidFinishLoading
{
    [self batchDidFinish];
    
    DDLogVerbose(@"Project finished loading");
    
    self.isLoadingProject = NO;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:XCCProjectDidFinishLoadingNotification object:self];
    [[NSUserDefaults standardUserDefaults] setObject:self.cappuccinoProject.projectPath forKey:kDefaultXCCLastOpenedProjectPath];
    
    [CappuccinoUtils notifyUserWithTitle:@"Project loaded" message:self.cappuccinoProject.projectPath.lastPathComponent];
    
    [self startListenProject];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDefaultXCCAutoOpenXcodeProject])
        [self openXcodeProject:self];
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

- (void)resetProject
{
    NSString *projectPath = self.cappuccinoProject.projectPath;
    
    [self stopListenProject];
    [self.operationQueue cancelAllOperations];
    
    [self removeSupportFilesAtPath];
    [self removeAllCibsAtPath:[projectPath stringByAppendingPathComponent:@"Resources"]];
    
    [self _init];
}

- (void)removeAllCibsAtPath:(NSString *)path
{
    NSArray *paths = [self.fm contentsOfDirectoryAtPath:path error:nil];
    
    for (NSString *filePath in paths)
    {
        if ([filePath.pathExtension.lowercaseString isEqualToString:@"cib"])
            [self.fm removeItemAtPath:[path stringByAppendingPathComponent:filePath] error:nil];
    }
}

- (void)removeSupportFilesAtPath
{
    [XcodeProjectCloser closeXcodeProjectForProject:self.cappuccinoProject.projectPath];
    
    [self.fm removeItemAtPath:self.cappuccinoProject.xcodeProjectPath error:nil];
    [self.fm removeItemAtPath:self.cappuccinoProject.supportPath error:nil];
}

@end
