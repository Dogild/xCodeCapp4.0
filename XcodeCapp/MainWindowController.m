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


#pragma mark - Initialization

- (void)windowDidLoad
{
    [self _showMaskingView:YES];
    [self _startListeningToNotifications];
    [self _restoreManagedProjectsFromUserDefaults];
    [self _selectLastProjectSelected];
}


#pragma mark - Notifications

- (void)_startListeningToNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self selector:@selector(_didReceiveStartListeningToProjectNotification:) name:XCCStartListeningProjectNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveStopListeningToProjectNotification:) name:XCCStopListeningProjectNotification object:nil];
}

- (void)_didReceiveStartListeningToProjectNotification:(NSNotification*)aNotification
{
    CappuccinoProject *cappuccinoProject = [aNotification object];
    NSMutableArray *previousHistoryLoadedPaths = [[[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCLastLoadedProjectPath] mutableCopy];
    
    if (!previousHistoryLoadedPaths)
        previousHistoryLoadedPaths = [NSMutableArray array];
    
    if (![previousHistoryLoadedPaths containsObject:cappuccinoProject.projectPath])
        [previousHistoryLoadedPaths addObject:cappuccinoProject.projectPath];
    
    [[NSUserDefaults standardUserDefaults] setObject:previousHistoryLoadedPaths forKey:kDefaultXCCLastLoadedProjectPath];
}

- (void)_didReceiveStopListeningToProjectNotification:(NSNotification*)aNotification
{
    CappuccinoProject *cappuccinoProject = [aNotification object];
    NSMutableArray *previousHistoryLoadedPaths = [[[NSUserDefaults standardUserDefaults] objectForKey:kDefaultXCCLastLoadedProjectPath] mutableCopy];
    
    if (!previousHistoryLoadedPaths)
        previousHistoryLoadedPaths = [NSMutableArray array];
    
    if ([previousHistoryLoadedPaths containsObject:cappuccinoProject.projectPath])
        [previousHistoryLoadedPaths removeObject:cappuccinoProject.projectPath];
    
    [[NSUserDefaults standardUserDefaults] setObject:previousHistoryLoadedPaths forKey:kDefaultXCCLastLoadedProjectPath];
}


#pragma mark - Custom Getters and Setters

- (CappuccinoProjectController*)currentCappuccinoProjectController
{
    return [self.cappuccinoProjectControllers objectAtIndex:[self.projectTableView selectedRow]];
}


#pragma mark - Utilities

- (void)_selectLastProjectSelected
{
    DDLogVerbose(@"Start : selecting last selected project");
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *lastSelectedProjectPath = [defaults valueForKey:kDefaultXCCLastSelectedProjectPath];
    NSInteger indexToSelect = 0;
    
    if (lastSelectedProjectPath)
    {
        for (CappuccinoProjectController *controller in self.cappuccinoProjectControllers)
        {
            if ([controller.cappuccinoProject.projectPath isEqualToString:lastSelectedProjectPath])
            {
                indexToSelect = [self.cappuccinoProjectControllers indexOfObject:controller];
                break;
            }
        }
    }
    
    [self.projectTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:indexToSelect] byExtendingSelection:NO];
    
    DDLogVerbose(@"Stop : selecting last selected project");
}

- (void)_showMaskingView:(BOOL)shouldShow
{
    if (shouldShow)
    {
        if (self.maskingView.superview)
            return;
        
        [self.projectViewContainer setHidden:YES]; // try to remove and laught..
        
        self.maskingView.frame = [[[self.splitView subviews] objectAtIndex:1] bounds];
        [[[self.splitView subviews] objectAtIndex:1] addSubview:self.maskingView positioned:NSWindowAbove relativeTo:nil];
    }
    else
    {
        if (!self.maskingView.superview)
            return;
        
        [self.projectViewContainer setHidden:NO]; // try to remove and laught..
        
        [self.maskingView removeFromSuperview];
    }
    

}


#pragma mark - Application Lifecycle

- (void)notifyCappuccinoControllersApplicationIsClosing
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:XCCStopListeningProjectNotification object:nil];
    
    for (int i; i < self.cappuccinoProjectControllers.count; i++)
        [[self.cappuccinoProjectControllers objectAtIndex:i] notifyCappuccinoControllersApplicationIsClosing];
}


#pragma mark - Projects history

- (void)_restoreManagedProjectsFromUserDefaults
{
    DDLogVerbose(@"Start : fetching historic projects");
    self.cappuccinoProjectControllers = [NSMutableArray new];
    
    NSArray *projectHistory = [[NSUserDefaults standardUserDefaults] arrayForKey:kDefaultXCCCurrentManagedProjects];
    
    for (NSString *path in projectHistory)
    {
        CappuccinoProjectController *cappuccinoProjectController = [[CappuccinoProjectController alloc] initWithPath:path controller:self];
        [self.cappuccinoProjectControllers addObject:cappuccinoProjectController];
    }
    
    [self.projectTableView reloadData];
    
    DDLogVerbose(@"Stop : fetching historic projects");
}

- (void)_saveManagedProjectsToUserDefaults
{
    NSMutableArray *historyProjectPaths = [NSMutableArray array];
    
    for (CappuccinoProjectController *controller in self.cappuccinoProjectControllers)
        [historyProjectPaths addObject:controller.cappuccinoProject.projectPath];
    
    [[NSUserDefaults standardUserDefaults] setObject:historyProjectPaths forKey:kDefaultXCCCurrentManagedProjects];
}


#pragma mark - Public Utilities

- (void)removeCappuccinoProject:(CappuccinoProjectController*)aController
{
    NSInteger selectedCappuccinoProject = [self.cappuccinoProjectControllers indexOfObject:aController];
    
    if (selectedCappuccinoProject == -1)
        return;
    
    [self.projectTableView deselectRow:selectedCappuccinoProject];
    [aController cleanUpBeforeDeletion];
    [self.cappuccinoProjectControllers removeObjectAtIndex:selectedCappuccinoProject];
    [self.projectTableView reloadData];
    
    [self _saveManagedProjectsToUserDefaults];
}

- (void)addCappuccinoProjectWithPath:(NSString*)aProjectPath
{
    CappuccinoProjectController *cappuccinoProjectController = [[CappuccinoProjectController alloc] initWithPath:aProjectPath controller:self];

    [self.cappuccinoProjectControllers addObject:cappuccinoProjectController];
    
    NSInteger index = [self.cappuccinoProjectControllers indexOfObject:cappuccinoProjectController];

    [self.projectTableView reloadData];
    [self.projectTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    [self.projectTableView scrollRowToVisible:index];
    [self _saveManagedProjectsToUserDefaults];
    
    [CappuccinoUtils notifyUserWithTitle:@"Cappuccino project added" message:aProjectPath];
}

- (void)reloadErrorsListForCurrentCappuccinoProject
{
    [self.errorOutlineView reloadData];
    [self.errorOutlineView expandItem:nil expandChildren:YES];
}

- (void)reloadOperationsListForCurrentCappuccinoProject
{
    [self.operationTableView reloadData];
}


#pragma mark - Actions

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
    [self addCappuccinoProjectWithPath:projectPath];
}

- (IBAction)removeProject:(id)aSender
{
    NSInteger selectedCappuccinoProject = [self.projectTableView selectedRow];
    
    if (selectedCappuccinoProject == -1)
        return;
    
    [self removeCappuccinoProject:[self.cappuccinoProjectControllers objectAtIndex:selectedCappuccinoProject]];
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
    return [self.cappuccinoProjectControllers count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    CappuccinoProjectCellView   *cellView                    = [tableView makeViewWithIdentifier:@"MainCell" owner:nil];
    CappuccinoProjectController *cappuccinoProjectController = [self.cappuccinoProjectControllers objectAtIndex:row];
    CappuccinoProject           *cappuccinoProject           =[cappuccinoProjectController cappuccinoProject];
    
    cellView.cappuccinoProject = cappuccinoProject;
    
    [cellView.loadButton setTarget:cappuccinoProjectController];
    [cellView.loadButton setAction:@selector(switchProjectListeningStatus:)];
    
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
        
        [self _showMaskingView:YES];
        return;
    }
    
    CappuccinoProjectController *currentController = [self.cappuccinoProjectControllers objectAtIndex:selectedCappuccinoProject];
    
    self.currentCappuccinoProject = [currentController cappuccinoProject];
    [self.operationTableView setDelegate:currentController];
    [self.operationTableView setDataSource:currentController];
    
    [self _showMaskingView:NO];
    
    [self.errorOutlineView setDelegate:currentController];
    [self.errorOutlineView setDataSource:currentController];
    [self.errorOutlineView setDoubleAction:@selector(openObjjFile:)];
    [self.errorOutlineView setTarget:currentController];
    
    // This can't be bound because we can't save an indexSet in a plist
    [[NSUserDefaults standardUserDefaults] setObject:self.currentCappuccinoProject.projectPath forKey:kDefaultXCCLastSelectedProjectPath];
}

@end
