//
//  MainController.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "MainController.h"
#import "CappuccinoProject.h"
#import "CappuccinoProjectController.h"
#import "CappuccinoProjectViewCell.h"
#import "UserDefaults.h"

@implementation MainController

- (CappuccinoProjectController*)currentCappuccinoProjectController
{
    return [self.cappuccinoProjectController objectAtIndex:[self.projectTableView selectedRow]];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    for (CappuccinoProjectController *controller in self.cappuccinoProjectController)
    {
        [controller stopListenProject];
    }
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
        [cappuccinoProjectController setMainController:self];
        [self.cappuccinoProjectController addObject:cappuccinoProjectController];
        [cappuccinoProjectController setOperationTableView:self.operationTableView];
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
    CappuccinoProjectViewCell *cellView = [tableView makeViewWithIdentifier:@"MainCell" owner:nil];
    
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
    
    // This can't be bound because we can't save an indexSet in a plis
    [[NSUserDefaults standardUserDefaults] setObject:self.currentCappuccinoProject.projectPath forKey:kDefaultXCCLastSelectedProjectPath];
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
    
    [self.projectTableView deselectRow:selectedCappuccinoProject];
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
    
    CappuccinoProjectController *cappuccinoProjectController = [[CappuccinoProjectController alloc] initWithPath:projectPath];
    [self.cappuccinoProjectController addObject:cappuccinoProjectController];
    
    [self.projectTableView reloadData];
    [self.projectTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[self.cappuccinoProjectController indexOfObject:cappuccinoProjectController]] byExtendingSelection:NO];
    [self saveCurrentProjects];
}

- (IBAction)saveSettings:(id)aSender
{
    [[self currentCappuccinoProjectController] save:aSender];
}

- (IBAction)cancelAllOperations:(id)aSender
{
    [[self currentCappuccinoProjectController] cancelAllOperations:aSender];
}

@end
