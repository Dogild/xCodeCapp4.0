//
//  CappuccinoProject.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#include <fcntl.h>

#import "CappuccinoProject.h"
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

// Where we put the generated Cocoa class files
static NSString * const XCCSupportFolderName = @".XcodeSupport";

// We store a compatibility version in .XcodeSupport/Info.plist.
// If the version is less than the version in XcodeCapp's Info.plist, we regenerate .XcodeSupport.
static NSString * const XCCCompatibilityVersionKey = @"XCCCompatibilityVersion";

// Paths used by this project
static NSString * const XCCCappuccinoProjectBinPaths = @"XCCCappuccinoProjectBinPaths";

// Default environement paths
static NSArray* XCCDefaultEnvironmentPaths;


// When scanning the project, we immediately ignore directories that match this regex.
static NSString * const XCCDirectoriesToIgnorePattern = @"^(?:Build|F(?:rameworks|oundation)|AppKit|Objective-J|(?:Browser|CommonJS)\\.environment|Resources|XcodeSupport|.+\\.xcodeproj)$";

// The regex above is used with this predicate for testing.
static NSPredicate * XCCDirectoriesToIgnorePredicate = nil;

// An array of the default predicates used to ignore paths.
static NSArray *XCCDefaultIgnoredPathPredicates = nil;


NSString * const XCCCappLintDidStartNotification = @"XCCCappLintDidStartNotification";
NSString * const XCCCappLintDidEndNotification = @"XCCCappLintDidEndNotification";
NSString * const XCCObjjDidStartNotification = @"XCCObjjDidStartNotification";
NSString * const XCCObjjDidEndNotification = @"XCCObjjDidEndNotification";


@interface CappuccinoProject ()

@property NSFileManager *fm;

@property (nonatomic) TaskManager *taskManager;

// Full path to .xcodecapp-ignore
@property NSString *xcodecappIgnorePath;

@end


@implementation CappuccinoProject

#pragma mark - Class methods

+ (void)initialize
{
    if (self != [CappuccinoProject class])
        return;
    
    XCCDefaultEnvironmentPaths = [NSArray arrayWithObjects:@"/usr/local/narwhal/bin", @"~/narwhal/bin", nil];
    
    // Initialize static values that can't be initialized in their declarations
    
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
        
        self.errorList = [NSMutableArray array];
        self.warningList = [NSMutableArray array];
        self.processingFilesList = [NSMutableArray array];
        
        
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
    
    [self prepareXcodeSupport];
    [self initTaskManager];
    [self populateXcodeProject];
//    [self populatexCodeCappTargetedFiles];
//    [self waitForOperationQueueToFinishWithSelector:@selector(projectDidFinishLoading)];
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
    
    NSNumber *appCompatibilityVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:XCCCompatibilityVersionKey];
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:@{ XCCCompatibilityVersionKey:appCompatibilityVersion}
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
    FindSourceFilesOperation *op = [[FindSourceFilesOperation alloc] initWithXCC:self projectId:[NSNumber numberWithInteger:self.projectId] path:path];
    [self.operationQueue addOperation:op];
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

@end
