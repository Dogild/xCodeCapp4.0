//
//  CappuccinoProject.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#include <fcntl.h>

#import "CappuccinoProject.h"
#import "CappuccinoUtils.h"
#import "FindSourceFilesOperation.h"
#import "ProcessSourceOperation.h"
#import "TaskManager.h"

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

// We replace "/" in a path with this. It looks like "/",
// but is actually an obscure Unicode character we hope no one uses in a filename.
static NSString * const XCCSlashReplacement = @"∕";  // DIVISION SLASH, Unicode: U+2215

// Where we put the generated Cocoa class files
static NSString * const XCCSupportFolderName = @".XcodeSupport";

// We store a compatibility version in .XcodeSupport/Info.plist.
// If the version is less than the version in XcodeCapp's Info.plist, we regenerate .XcodeSupport.
static NSString * const XCCCompatibilityVersionKey = @"XCCCompatibilityVersion";

// Bin paths used by this project
static NSString * const XCCCappuccinoProjectBinPaths = @"XCCCappuccinoProjectBinPaths";

// Project should process capp lint or not
static NSString * const XCCCappuccinoProcessCappLint = @"XCCCappuccinoProcessCappLint";

// Project should process capp lint or not
static NSString * const XCCCappuccinoProcessObjj = @"XCCCappuccinoProcessObjj";

// Default environement paths
static NSArray* XCCDefaultEnvironmentPaths;

// Default info plist XCCDefaultInfoPlistConfigurations
static NSDictionary* XCCDefaultInfoPlistConfigurations;

NSString * const XCCCappLintDidStartNotification = @"XCCCappLintDidStartNotification";
NSString * const XCCCappLintDidEndNotification = @"XCCCappLintDidEndNotification";
NSString * const XCCObjjDidStartNotification = @"XCCObjjDidStartNotification";
NSString * const XCCObjjDidEndNotification = @"XCCObjjDidEndNotification";


@interface CappuccinoProject ()

@property NSFileManager *fm;

// Full path to .xcodecapp-ignore
@property NSString *xcodecappIgnorePath;

// A queue for threaded operations to perform
@property NSOperationQueue *operationQueue;

@end


@implementation CappuccinoProject

#pragma mark - Class methods

+ (void)initialize
{
    if (self != [CappuccinoProject class])
        return;
    
    XCCDefaultEnvironmentPaths = [NSArray arrayWithObjects:@"/usr/local/narwhal/bin", @"~/narwhal/bin", nil];
    
    NSNumber *appCompatibilityVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey];
                    
    XCCDefaultInfoPlistConfigurations = @{XCCCompatibilityVersionKey: appCompatibilityVersion,
                                          XCCCappuccinoProcessCappLint: @YES,
                                          XCCCappuccinoProcessObjj: @YES,
                                          XCCCappuccinoProjectBinPaths: XCCDefaultEnvironmentPaths};
}

#pragma mark - Init methods

- (id)initWithPath:(NSString*)aPath
{
    self = [super init];
    
    if (self)
    {
        self.fm = [NSFileManager defaultManager];
        self.parserPath = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"parser.j"];
        self.projectPath = aPath;
        self.xcodecappIgnorePath = [self.projectPath stringByAppendingPathComponent:@".xcodecapp-ignore"];
        self.pbxModifierScriptPath = [[NSBundle mainBundle].sharedSupportPath stringByAppendingPathComponent:@"pbxprojModifier.py"];
        
        NSString *projectName = [self.projectPath.lastPathComponent stringByAppendingString:@".xcodeproj"];
        
        self.xcodeProjectPath = [self.projectPath stringByAppendingPathComponent:projectName];
        self.supportPath = [self.projectPath stringByAppendingPathComponent:XCCSupportFolderName];
        self.infoPlistPath = [self.supportPath stringByAppendingPathComponent:@"Info.plist"];
        
        self.projectPathsForSourcePaths = [NSMutableDictionary new];
        
        self.operationQueue = [NSOperationQueue new];
        
        self.errorList = [NSMutableArray array];
        self.warningList = [NSMutableArray array];
        self.currentOperations = [NSMutableArray array];
        
        self.isLoadingProject = NO;
        self.isListeningProject = NO;
        self.isProcessingProject = NO;
    }
    
    return self;
}

- (TaskManager*)makeTaskManager
{
    TaskManager *taskManager = [[TaskManager alloc] initWithEnvironementPaths:self.environementsPaths];
    
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
    DDLogInfo(@"Loading project: %@", self.projectPath);
    self.isLoadingProject = YES;
    
    [self initObservers];
    [self prepareIgnoredPaths];
    [self prepareXcodeSupport];
    [self initTaskManager];
    [self populateXcodeProject];
    //[self populatexCodeCappTargetedFiles];
    //[self waitForOperationQueueToFinishWithSelector:@selector(projectDidFinishLoading)];
}

- (void)prepareIgnoredPaths
{
    self.ignoredPathPredicates = [NSMutableArray new];
    
    if ([self.fm fileExistsAtPath:self.xcodecappIgnorePath])
    {
        NSString *ignoreFileContent = [NSString stringWithContentsOfFile:self.xcodecappIgnorePath encoding:NSUTF8StringEncoding error:nil];
        NSArray *ignoredPatterns = [ignoreFileContent componentsSeparatedByString:@"\n"];
        NSArray *parsedPaths = [CappuccinoUtils parseIgnorePaths:ignoredPatterns];
        [self.ignoredPathPredicates addObjectsFromArray:parsedPaths];
    }
    
    DDLogVerbose(@"Ignoring file paths: %@", self.ignoredPathPredicates);
}

/*!
 Create Xcode project and .XcodeSupport directory if necessary.
 
 @return YES if both exist
 */
- (BOOL)prepareXcodeSupport
{
    // If either the project or the supmport directory are missing, recreate them both to ensure they are in sync
    BOOL projectExists, projectIsDirectory;
    projectExists = [self.fm fileExistsAtPath:self.xcodeProjectPath isDirectory:&projectIsDirectory];
    
    BOOL supportExists, supportIsDirectory;
    supportExists = [self.fm fileExistsAtPath:self.supportPath isDirectory:&supportIsDirectory];
    
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
    
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:self.infoPlistPath];
    NSNumber *projectCompatibilityVersion = info[XCCCompatibilityVersionKey];
    
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
    if ([self.fm fileExistsAtPath:self.xcodeProjectPath])
        [self.fm removeItemAtPath:self.xcodeProjectPath error:nil];
    
    [self.fm createDirectoryAtPath:self.xcodeProjectPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *pbxPath = [self.xcodeProjectPath stringByAppendingPathComponent:@"project.pbxproj"];
    
    [self.fm copyItemAtPath:[[NSBundle mainBundle] pathForResource:@"project" ofType:@"pbxproj"] toPath:pbxPath error:nil];
    
    NSMutableString *content = [NSMutableString stringWithContentsOfFile:pbxPath encoding:NSUTF8StringEncoding error:nil];
    
    [content writeToFile:pbxPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    DDLogInfo(@"Xcode support project created at: %@", self.xcodeProjectPath);
}


- (void)createXcodeSupportDirectory
{
    if ([self.fm fileExistsAtPath:self.supportPath])
        [self.fm removeItemAtPath:self.supportPath error:nil];
    
    [self.fm createDirectoryAtPath:self.supportPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:XCCDefaultInfoPlistConfigurations
                                                              format:NSPropertyListXMLFormat_v1_0
                                                    errorDescription:nil];
    
    [data writeToFile:self.infoPlistPath atomically:YES];
    
    DDLogInfo(@".XcodeSupport directory created at: %@", self.supportPath);
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
    FindSourceFilesOperation *op = [[FindSourceFilesOperation alloc] initWithCappuccinoProject:self path:path];
    [self.operationQueue addOperation:op];
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
    return note.userInfo[@"cappuccinoProject"] == self;
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
    
    self.projectPathsForSourcePaths[info[@"sourcePath"]] = info[@"projectPath"];
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
    
    [self.currentOperations addObject:info[@"operation"]];
    
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
    
    [self.currentOperations addObject:info[@"operation"]];
    
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
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:self.infoPlistPath];
    NSArray *paths = info[XCCCappuccinoProjectBinPaths];
    
    if ([paths count])
        self.environementsPaths = [paths copy];
    else
        self.environementsPaths = XCCDefaultEnvironmentPaths;

    self.taskManager = [self makeTaskManager];
}


#pragma mark path methods

- (NSString *)projectRelativePathForPath:(NSString *)path
{
    return [path substringFromIndex:self.projectPath.length + 1];
}

- (BOOL)isXCCIgnoreFile:(NSString *)path
{
    return [path isEqualToString:self.xcodecappIgnorePath];
}


#pragma mark - Shadow Files Management

- (NSString *)shadowBasePathForProjectSourcePath:(NSString *)path
{
    if (path.isAbsolutePath)
        path = [self projectRelativePathForPath:path];
    
    NSString *filename = [path.stringByDeletingPathExtension stringByReplacingOccurrencesOfString:@"/" withString:XCCSlashReplacement];
    
    return [self.supportPath stringByAppendingPathComponent:filename];
}


#pragma mark - Events methods

- (void)startListenProject
{
    DDLogInfo(@"Start listen project: %@", self.projectPath);
    self.isListeningProject = YES;
}

- (void)stopListenProject
{
    DDLogInfo(@"Stop listen project: %@", self.projectPath);
    self.isListeningProject = NO;
}

#pragma mark - Info plist configurations

- (BOOL)shouldProcessWithObjjWarnings
{
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:self.infoPlistPath];
    return !!info[XCCCappuccinoProcessObjj];
}

- (BOOL)shouldProcessWithCappLint
{
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:self.infoPlistPath];
    return !!info[XCCCappuccinoProcessCappLint];
}

@end
