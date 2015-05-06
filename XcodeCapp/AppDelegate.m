//
//  AppDelegate.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/5/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    [self initLogging];
    DDLogVerbose(@"\n******************************\n**    XcodeCapp started     **\n******************************\n");
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    
    DDLogVerbose(@"\n******************************\n**    XcodeCapp stopped     **\n******************************\n");
}

#pragma mark - Window managements

- (void)openWindow:(NSWindow *)aWindow
{
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [aWindow makeKeyAndOrderFront:nil];
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
    int logLevel = (int)[defaults integerForKey:kDefaultLogLevel];
    NSUInteger modifiers = [NSEvent modifierFlags];
    
    if (modifiers & NSAlternateKeyMask)
        logLevel = LOG_LEVEL_VERBOSE;
    
    [DDLogLevel setLogLevel:logLevel];
#endif
}


#pragma mark - SplitView delegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return 300;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return 200;
}

@end
