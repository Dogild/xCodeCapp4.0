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

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    [self registerDefaultPreferences];
    [self initLogging];
    DDLogVerbose(@"\n******************************\n**    XcodeCapp started     **\n******************************\n");
    
    self.aboutWindow.backgroundColor = [NSColor whiteColor];
    [self.mainWindowController windowDidLoad];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)app
{
    DDLogVerbose(@"Stop listening to all projects");
    [self.mainWindowController notifyCappuccinoControllersApplicationIsClosing];
    
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
