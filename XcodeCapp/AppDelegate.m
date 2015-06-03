//
//  AppDelegate.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/5/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "AppDelegate.h"
#import "XCCMainController.h"
#import "UserDefaults.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    DDLogVerbose(@"\n******************************\n**    XcodeCapp started     **\n******************************\n");
    
    self.mainOperationQueue = [NSOperationQueue new];
    
    [self registerDefaultPreferences];
    [self initLogging];
    [self _initStatusItem];
    
    [self.mainWindowController windowDidLoad];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app
{
    DDLogVerbose(@"Stop listening to all projects");
    [self.mainWindowController notifyCappuccinoControllersApplicationIsClosing];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return NSTerminateNow;
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    
    // Insert code here to tear down your application
    DDLogVerbose(@"\n******************************\n**    XcodeCapp stopped     **\n******************************\n");
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    [self.mainWindowController showWindow:self];
    return YES;
}

- (BOOL)application:(NSApplication *)application openFile:(NSString *)filename
{
    BOOL isDir;
    
    [[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir];
    
    if (isDir)
    {
        [self.mainWindowController addCappuccinoProjectWithPath:filename];
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void)_initStatusItem
{
    self.iconInactive   = [NSImage imageNamed:@"status-icon-inactive"];
    self.iconWorking    = [NSImage imageNamed:@"status-icon-working"];
    self.iconError      = [NSImage imageNamed:@"status-icon-error"];
    
    self.statusItem                 = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.menu            = self.statusMenu;
    self.statusItem.image           = self.iconInactive;
    self.statusItem.highlightMode   = YES;
    self.statusItem.length          = self.iconInactive.size.width + 12;
    
    [self.mainOperationQueue addObserver:self forKeyPath:@"operationCount" options:0 context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (self.mainOperationQueue.operationCount)
        [self.statusItem performSelectorOnMainThread:@selector(setImage:) withObject:self.iconWorking waitUntilDone:NO];
    else
        [self.statusItem performSelectorOnMainThread:@selector(setImage:) withObject:self.iconInactive waitUntilDone:NO];
}

#pragma mark - Window managements

- (void)openWindow:(NSWindow *)aWindow
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [aWindow makeKeyAndOrderFront:nil];
}


#pragma matk - Preferences window management

- (IBAction)openPreferences:(id)aSender
{
    [self openWindow:self.preferencesWindow];
}


#pragma mark - About window management

- (IBAction)openAbout:(id)aSender
{
    [self openWindow:self.aboutWindow];
}

- (NSString *)bundleVersion
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}


#pragma mark - User Defaults

- (void)registerDefaultPreferences
{
    NSDictionary *appDefaults = @{
                                kDefaultXCCAutoOpenXcodeProject: @YES,
                                kDefaultXCCLogLevel: [NSNumber numberWithInt:LOG_LEVEL_WARN],
                                kDefaultXCCMaxNumberOfOperations: @20
                                };
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults registerDefaults:appDefaults];
    [defaults synchronize];
}

#pragma mark - Logging methods

- (void)initLogging
{
#if DEBUG
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
    [[DDTTYLogger sharedInstance] setColorsEnabled:YES];
    [DDLogLevel setLogLevel:LOG_LEVEL_VERBOSE];
#else
    [DDLog addLogger:[DDASLLogger sharedInstance]];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int logLevel = (int)[defaults integerForKey:kDefaultXCCLogLevel];
    NSUInteger modifiers = [NSEvent modifierFlags];
    
    if (modifiers & NSAlternateKeyMask)
        logLevel = LOG_LEVEL_VERBOSE;
    
    [DDLogLevel setLogLevel:logLevel];
#endif
}

@end
