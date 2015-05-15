//
//  AppDelegate.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/5/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "AppDelegate.h"
#import "Cappuccino.h"
#import "CappuccinoProject.h"
#import "CappuccinoProjectController.h"
#import "CappuccinoProjectViewCell.h"
#import "UserDefaults.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet CappuccinoProjectController *currentCappuccinoProjectController;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    [self registerDefaultPreferences];
    [self initLogging];
    DDLogVerbose(@"\n******************************\n**    XcodeCapp started     **\n******************************\n");
    
    self.aboutWindow.backgroundColor = [NSColor whiteColor];
    [self pruneProjectHistory];
    [self fetchProjects];
    [self selectLastProjectSelected];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
    
    for (CappuccinoProjectController *controller in self.cappuccinoProjectController)
    {
        [controller stopListenProject];
    }
    
    DDLogVerbose(@"\n******************************\n**    XcodeCapp stopped     **\n******************************\n");
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
                                kDefaultXCCMaxRecentProjects: @20,
                                kDefaultXCCReopenLastProject: @YES,
                                kDefaultXCCUpdateCappuccinoWithLastVersionOfMasterBranch: @NO,
                                kDefaultXCCUseSymlinkWhenCreatingProject: @YES,
                                kDefaultXCCLogLevel: [NSNumber numberWithInt:LOG_LEVEL_WARN]
                                };
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults registerDefaults:appDefaults];
    [defaults synchronize];
    
    [defaults addObserver:self
               forKeyPath:kDefaultXCCMaxRecentProjects
                  options:NSKeyValueObservingOptionNew
                  context:NULL];
}

// Watch changes to the max recent projects preference
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:kDefaultXCCMaxRecentProjects])
    {
        [self pruneProjectHistory];
        [self fetchProjects];
    }
}


#pragma mark - Projects history

/*
 This method is used to remove project from the history if needed. 
 It will be removed when having too many projects or when a project does not exist anymore
 */
- (void)pruneProjectHistory
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *projectHistory = [[defaults arrayForKey:kDefaultXCCProjectHistory] mutableCopy];
    NSFileManager *fm = [NSFileManager new];
    
    for (NSInteger i = projectHistory.count - 1; i >= 0; --i)
    {
        if (![fm fileExistsAtPath:projectHistory[i]])
            [projectHistory removeObjectAtIndex:i];
    }
    
    NSInteger maxProjects = [defaults integerForKey:kDefaultXCCMaxRecentProjects];
    
    if (projectHistory.count > maxProjects)
        [projectHistory removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(maxProjects, projectHistory.count - maxProjects)]];
    
    [defaults setObject:projectHistory forKey:kDefaultXCCProjectHistory];
}

- (void)fetchProjects
{
    DDLogVerbose(@"Start : fetching historic projects");
    
    self.cappuccinoProjectController = [NSMutableArray new];
    
    NSArray *projectHistory = [[NSUserDefaults standardUserDefaults] arrayForKey:kDefaultXCCProjectHistory];
    
    for (NSString *path in projectHistory)
    {
        CappuccinoProjectController *cappuccinoProjectController = [[CappuccinoProjectController alloc] initWithPath:path];
        [self.cappuccinoProjectController addObject:cappuccinoProjectController];
    }
    
    [self.projectTableView reloadData];
    
    DDLogVerbose(@"Stop : fetching historic projects");
}

- (void)selectLastProjectSelected
{
    DDLogVerbose(@"Start : selecting last selected project");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];    
    NSString *lastSelectedProjectPath = [defaults valueForKey:kDefaultXCCLastSelectedProjectPath];
    NSInteger indexToSelect = 0;
        
    if (lastSelectedProjectPath)
    {
        for (CappuccinoProjectController *controller in self.cappuccinoProjectController)
        {
            if ([controller.cappuccinoProject.projectPath isEqualToString:lastSelectedProjectPath])
            {
                indexToSelect = [self.cappuccinoProjectController indexOfObject:controller];
                break;
            }
        }
    }
    
    [self.projectTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:indexToSelect] byExtendingSelection:NO];
    
    DDLogVerbose(@"Start : selecting last selected project");
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


#pragma mark - SplitView delegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return 300;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return 200;
}

#pragma mark - TableView delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.cappuccinoProjectController count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    CappuccinoProjectViewCell *cellView = [tableView makeViewWithIdentifier:@"MainCell" owner:nil];
    
    CappuccinoProject *cappuccinoProject = [[self.cappuccinoProjectController objectAtIndex:row] cappuccinoProject];
    
    [cellView.textField setStringValue:[cappuccinoProject projectName]];
    [cellView.pathTextField setStringValue:[cappuccinoProject projectPath]];
    
    // No idea why I have to that here, does not work from the xib...
    [cellView.loadButton setAction:@selector(loadProject:)];
    [cellView.loadButton setTarget:self];
    
    return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger selectedCappuccinoProject = [self.projectTableView selectedRow];
    self.currentCappuccinoProjectController = [self.cappuccinoProjectController objectAtIndex:selectedCappuccinoProject];
    
    // This can't be bound because we can't save an indexSet in a plis
    [[NSUserDefaults standardUserDefaults] setObject:self.currentCappuccinoProjectController.cappuccinoProject.projectPath forKey:kDefaultXCCLastSelectedProjectPath];
}

- (IBAction)loadProject:(id)aSender
{
    CappuccinoProjectController *cappuccinoProjectController = [self.cappuccinoProjectController objectAtIndex:[self.projectTableView rowForView:aSender]];
    
    [cappuccinoProjectController loadProject];
    
}

@end
