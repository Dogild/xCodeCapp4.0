//
//  MainWindowController.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "MainWindowController.h"
#import "CappuccinoProject.h"
#import "CappuccinoProjectController.h"
#import "CappuccinoProjectCellView.h"
#import "CappuccinoUtils.h"
#import "UserDefaults.h"

@implementation MainWindowController

- (void)awakeFromNib
{
    [self initObservers];
    [self pruneProjectHistory];
    [self fetchProjects];
}

- (void)windowDidLoad
{
    [self selectLastProjectSelected];
    [self loadLastProjectsLoaded];
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

- (void)initObservers
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self selector:@selector(startListeningProjectHandler:) name:XCCStartListeningProjectNotification object:nil];
    
    [center addObserver:self selector:@selector(stopListeningProjectHandler:) name:XCCStopListeningProjectNotification object:nil];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:kDefaultXCCMaxRecentProjects
                                               options:NSKeyValueObservingOptionNew
                                               context:NULL];
}

- (void)startListeningProjectHandler:(NSNotification*)aNotification
{
    CappuccinoProject *cappuccinoProject = [aNotification object];
    NSMutableArray *previousHistoryLoadedPaths = [[[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCLastLoadedProjectPath] mutableCopy];
    
    if (!previousHistoryLoadedPaths)
        previousHistoryLoadedPaths = [NSMutableArray array];
    
    if (![previousHistoryLoadedPaths containsObject:cappuccinoProject.projectPath])
        [previousHistoryLoadedPaths addObject:cappuccinoProject.projectPath];
    
    [[NSUserDefaults standardUserDefaults] setObject:previousHistoryLoadedPaths forKey:kDefaultXCCLastLoadedProjectPath];
}

- (void)stopListeningProjectHandler:(NSNotification*)aNotification
{
    CappuccinoProject *cappuccinoProject = [aNotification object];
    NSMutableArray *previousHistoryLoadedPaths = [[[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCLastLoadedProjectPath] mutableCopy];
    
    if (!previousHistoryLoadedPaths)
        previousHistoryLoadedPaths = [NSMutableArray array];
    
    if ([previousHistoryLoadedPaths containsObject:cappuccinoProject.projectPath])
        [previousHistoryLoadedPaths removeObject:cappuccinoProject.projectPath];
    
    [[NSUserDefaults standardUserDefaults] setObject:previousHistoryLoadedPaths forKey:kDefaultXCCLastLoadedProjectPath];
}

- (CappuccinoProjectController*)currentCappuccinoProjectController
{
    return [self.cappuccinoProjectController objectAtIndex:[self.projectTableView selectedRow]];
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
    
    DDLogVerbose(@"Stop : selecting last selected project");
}

- (void)loadLastProjectsLoaded
{
    DDLogVerbose(@"Start : loading last loaded projects");
    
    NSArray *lastLoadedProjectPath = [[[NSUserDefaults standardUserDefaults] valueForKey:kDefaultXCCLastLoadedProjectPath] mutableCopy];
    
    for (CappuccinoProjectController *controller in self.cappuccinoProjectController)
    {
        if ([lastLoadedProjectPath containsObject:controller.cappuccinoProject.projectPath])
            [controller loadProject];
    }
    
    DDLogVerbose(@"Stop : loading last selected project");
}

- (void)saveCurrentProjects
{
    NSMutableArray *historyProjectPaths = [NSMutableArray array];
    
    for (CappuccinoProjectController *controller in self.cappuccinoProjectController)
        [historyProjectPaths addObject:controller.cappuccinoProject.projectPath];
    
    [[NSUserDefaults standardUserDefaults] setObject:historyProjectPaths forKey:kDefaultXCCProjectHistory];
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
        [cappuccinoProjectController setMainWindowController:self];
        [self.cappuccinoProjectController addObject:cappuccinoProjectController];
    }
    
    [self.projectTableView reloadData];
    
    DDLogVerbose(@"Stop : fetching historic projects");
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
    CappuccinoProjectCellView *cellView = [tableView makeViewWithIdentifier:@"MainCell" owner:nil];
    
    CappuccinoProject *cappuccinoProject = [[self.cappuccinoProjectController objectAtIndex:row] cappuccinoProject];
    
    // No idea why I have to that here, does not work from the xib...
    [cellView.loadButton setAction:@selector(loadProject:)];
    [cellView.loadButton setTarget:self];
    
    cellView.cappuccinoProject = cappuccinoProject;
    
    return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger selectedCappuccinoProject = [self.projectTableView selectedRow];
    
    if (selectedCappuccinoProject == -1)
    {
        self.currentCappuccinoProject = nil;
        [self.operationTableView setDelegate:nil];
        [self.operationTableView setDataSource:nil];
        return;
    }
    
    CappuccinoProjectController *currentController = [self.cappuccinoProjectController objectAtIndex:selectedCappuccinoProject];
    
    self.currentCappuccinoProject = [currentController cappuccinoProject];
    [self.operationTableView setDelegate:currentController];
    [self.operationTableView setDataSource:currentController];
    
    [self.errorOutlineView setDelegate:currentController];
    [self.errorOutlineView setDataSource:currentController];
    [self.errorOutlineView setDoubleAction:@selector(openObjjFile:)];
    [self.errorOutlineView setTarget:currentController];
    
    // This can't be bound because we can't save an indexSet in a plist
    [[NSUserDefaults standardUserDefaults] setObject:self.currentCappuccinoProject.projectPath forKey:kDefaultXCCLastSelectedProjectPath];
}

- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
    [self.errorOutlineView reloadData];
    [self.operationTableView reloadData];
}

#pragma mark - button bar project tableView

- (IBAction)loadProject:(id)aSender
{
    CappuccinoProjectController *cappuccinoProjectController = [self.cappuccinoProjectController objectAtIndex:[self.projectTableView rowForView:aSender]];
    
    if (cappuccinoProjectController.cappuccinoProject.isProjectLoaded && cappuccinoProjectController.cappuccinoProject.isListeningProject)
        [cappuccinoProjectController stopListenProject];
    else if (cappuccinoProjectController.cappuccinoProject.isProjectLoaded)
        [cappuccinoProjectController startListenProject];
    else
        [cappuccinoProjectController loadProject];
}

- (IBAction)removeProject:(id)aSender
{
    NSInteger selectedCappuccinoProject = [self.projectTableView selectedRow];
    
    if (selectedCappuccinoProject == -1)
        return;

    [self unlinkProject:[self.cappuccinoProjectController objectAtIndex:selectedCappuccinoProject]];
}

- (void)unlinkProject:(CappuccinoProjectController*)aController
{
    NSInteger selectedCappuccinoProject = [self.cappuccinoProjectController indexOfObject:aController];
    
    if (selectedCappuccinoProject == -1)
        return;
    
    [self.projectTableView deselectRow:selectedCappuccinoProject];
    [aController stopListenProject];
    [self.cappuccinoProjectController removeObjectAtIndex:selectedCappuccinoProject];
    [self.projectTableView reloadData];
    
    [self saveCurrentProjects];
}

- (IBAction)addProject:(id)aSender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.title = @"Add a new Cappuccino Project to XcodeCapp";
    openPanel.canCreateDirectories = YES;
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = NO;
    
    if ([openPanel runModal] != NSFileHandlingPanelOKButton)
        return;
    
    NSString *projectPath = [[openPanel.URLs[0] path] stringByStandardizingPath];
    [self addProjectPath:projectPath];
}

- (void)addProjectPath:(NSString*)aProjectPath
{
    CappuccinoProjectController *cappuccinoProjectController = [[CappuccinoProjectController alloc] initWithPath:aProjectPath];
    [self.cappuccinoProjectController addObject:cappuccinoProjectController];
    
    NSInteger index = [self.cappuccinoProjectController indexOfObject:cappuccinoProjectController];

    [self.projectTableView reloadData];
    [self.projectTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    [self.projectTableView scrollRowToVisible:index];
    [self saveCurrentProjects];
    
    [CappuccinoUtils notifyUserWithTitle:@"Cappuccino project added" message:aProjectPath];
    
    [cappuccinoProjectController loadProject];
}

- (IBAction)saveSettings:(id)aSender
{
    [[self currentCappuccinoProjectController] save:aSender];
}

- (IBAction)cancelAllOperations:(id)aSender
{
    [[self currentCappuccinoProjectController] cancelAllOperations:aSender];
}

- (IBAction)synchronizeProject:(id)aSender
{
    [[self currentCappuccinoProjectController] synchronizeProject:aSender];
}

- (IBAction)removeErrors:(id)aSender
{
    [[self currentCappuccinoProjectController] removeErrors:aSender];
}

- (IBAction)openXcodeProject:(id)aSender
{
    [[self currentCappuccinoProjectController] openXcodeProject:aSender];
}

@end