//
//  MainWindowController.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "NSMutableArray+moveIndexes.h"
#import "XCCMainController.h"
#import "XCCCappuccinoProject.h"
#import "XCCCappuccinoProjectController.h"
#import "XCCCappuccinoProjectControllerDataView.h"
#import "CappuccinoUtils.h"
#import "UserDefaults.h"
#import "XCCOperationsViewController.h"
#import "XCCErrorsViewController.h"
#import "XCCSettingsViewController.h"


@implementation XCCMainController

#pragma mark - Initialization

- (void)windowDidLoad
{
    [self _showMaskingView:YES];
    [self _showProjectsTableMaskingView:YES];
        
    [self _restoreManagedProjectsFromUserDefaults];
    [self _selectLastProjectSelected];
    
    NSTabViewItem *itemConfiguration = [[NSTabViewItem alloc] initWithIdentifier:@"configuration"];
    [itemConfiguration setView:self.settingsViewController.view];
    [self->tabViewProject addTabViewItem:itemConfiguration];
    
    NSTabViewItem *itemErrors = [[NSTabViewItem alloc] initWithIdentifier:@"errors"];
    [itemErrors setView:self.errorsViewController.view];
    [self->tabViewProject addTabViewItem:itemErrors];
    
    NSTabViewItem *itemOperations = [[NSTabViewItem alloc] initWithIdentifier:@"operations"];
    [itemOperations setView:self.operationsViewController.view];
    [self->tabViewProject addTabViewItem:itemOperations];
    
    NSMutableParagraphStyle *paragraphStyle= [NSMutableParagraphStyle new];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    
    NSDictionary *attrs = @{NSFontAttributeName: [NSFont systemFontOfSize:11],
                            NSForegroundColorAttributeName: [NSColor whiteColor],
                            NSParagraphStyleAttributeName: paragraphStyle};
    
    self->buttonSelectConfigurationTab.attributedTitle = [[NSMutableAttributedString alloc] initWithString:self->buttonSelectConfigurationTab.title attributes:attrs];
    self->buttonSelectErrorsTab.attributedTitle = [[NSMutableAttributedString alloc] initWithString:self->buttonSelectErrorsTab.title attributes:attrs];
    self->buttonSelectOperationsTab.attributedTitle = [[NSMutableAttributedString alloc] initWithString:self->buttonSelectOperationsTab.title attributes:attrs];
    
    [self updateSelectedTab:self->buttonSelectConfigurationTab];
    
    [self->projectTableView registerForDraggedTypes:[NSArray arrayWithObjects:@"projects", NSFilenamesPboardType, nil]];
}



#pragma mark - Private Utilities

- (void)_showMaskingView:(BOOL)shouldShow
{
    if (shouldShow)
    {
        if (self->maskingView.superview)
            return;
        
        [self->projectViewContainer setHidden:YES];
        
        self->maskingView.frame = [[[self->splitView subviews] objectAtIndex:1] bounds];
        [[[self->splitView subviews] objectAtIndex:1] addSubview:self->maskingView positioned:NSWindowAbove relativeTo:nil];
    }
    else
    {
        if (!self->maskingView.superview)
            return;
        
        [self->projectViewContainer setHidden:NO];
        
        [self->maskingView removeFromSuperview];
    }
}

- (void)_showProjectsTableMaskingView:(BOOL)shouldShow
{
    if (shouldShow)
    {
        if (self->viewProjectMask.superview)
            return;
        
        [self->projectTableView setHidden:YES];
        
        self->viewProjectMask.frame = [self->splitView.superview bounds];
        [self->splitView.superview addSubview:self->viewProjectMask positioned:NSWindowAbove relativeTo:nil];
    }
    else
    {
        if (!self->viewProjectMask.superview)
            return;
        
        [self->projectTableView setHidden:NO];
        
        [self->viewProjectMask removeFromSuperview];
    }
}

- (void)_selectLastProjectSelected
{
    DDLogVerbose(@"Start : selecting last selected project");
    
    NSUserDefaults  *defaults                = [NSUserDefaults standardUserDefaults];
    NSString        *lastSelectedProjectPath = [defaults valueForKey:kDefaultXCCLastSelectedProjectPath];
    NSInteger       indexToSelect            = 0;
    
    if ([lastSelectedProjectPath length])
    {
        for (XCCCappuccinoProjectController *controller in self.cappuccinoProjectControllers)
        {
            if ([controller.cappuccinoProject.projectPath isEqualToString:lastSelectedProjectPath])
            {
                indexToSelect = [self.cappuccinoProjectControllers indexOfObject:controller];
                break;
            }
        }
        
        [self->projectTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:indexToSelect] byExtendingSelection:NO];
    }
    
    
    DDLogVerbose(@"Stop : selecting last selected project");
}

- (void)_restoreManagedProjectsFromUserDefaults
{
    DDLogVerbose(@"Start : restore managed projects");
    self.cappuccinoProjectControllers = [NSMutableArray new];
    
    NSArray         *projectHistory  = [[NSUserDefaults standardUserDefaults] arrayForKey:kDefaultXCCCurrentManagedProjects];
    NSFileManager   *fm              = [NSFileManager defaultManager];
    NSMutableArray  *missingProjects = [NSMutableArray new];
    
    for (NSString *path in projectHistory)
    {
        if (![fm fileExistsAtPath:path isDirectory:nil])
        {
            [missingProjects addObject:path];
            continue;
        }
        
        XCCCappuccinoProjectController *cappuccinoProjectController = [[XCCCappuccinoProjectController alloc] initWithPath:path controller:self];
        [self.cappuccinoProjectControllers addObject:cappuccinoProjectController];
    }
    
    [self _reloadProjectsList];
    
    if (missingProjects.count)
    {
        NSRunAlertPanel(@"Missing Projects",
                        @"Some managed projects could not be found and have been removed:\n\n"
                        @"%@\n\n",
                        @"OK",
                        nil,
                        nil,
                        [missingProjects componentsJoinedByString:@", "]);

        [self _saveManagedProjectsToUserDefaults];
    }
    
    DDLogVerbose(@"Stop : managed  projects restored");
}

- (void)_saveSelectedProject
{
    NSString *path = self.currentCappuccinoProjectController.cappuccinoProject.projectPath;

    if (!path)
        path = @"";

    [[NSUserDefaults standardUserDefaults] setObject:path forKey:kDefaultXCCLastSelectedProjectPath];
}

- (void)_saveManagedProjectsToUserDefaults
{
    NSMutableArray *historyProjectPaths = [NSMutableArray array];

    for (XCCCappuccinoProjectController *controller in self.cappuccinoProjectControllers)
        [historyProjectPaths addObject:controller.cappuccinoProject.projectPath];

    [[NSUserDefaults standardUserDefaults] setObject:historyProjectPaths forKey:kDefaultXCCCurrentManagedProjects];
}

- (void)_reloadProjectsList
{
    [self->projectTableView reloadData];

    if (self.cappuccinoProjectControllers.count == 0)
        [self _showProjectsTableMaskingView:YES];
    else
        [self _showProjectsTableMaskingView:NO];
    
}


#pragma mark - Public Utilities

- (XCCCappuccinoProjectController *)createNewCappuccinoProjectControllerFromPath:(NSString *)path
{
    if ([[self.cappuccinoProjectControllers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"cappuccinoProject.projectPath == %@", path]] count])
    {
        NSRunAlertPanel(@"This project is already managed.", @"Please remove the other project or use the reset button.", @"OK", nil, nil, nil);
        return nil;
    }

    return [[XCCCappuccinoProjectController alloc] initWithPath:path controller:self];
}

- (void)manageCappuccinoProjectController:(XCCCappuccinoProjectController*)aController
{
    if (!aController)
        return;

    [self.cappuccinoProjectControllers addObject:aController];

    NSInteger index = [self.cappuccinoProjectControllers indexOfObject:aController];

    [self _reloadProjectsList];

    [self->projectTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    [self->projectTableView scrollRowToVisible:index];
    [self _saveManagedProjectsToUserDefaults];

    [aController switchProjectListeningStatus:self];
}

- (void)unmanageCappuccinoProjectController:(XCCCappuccinoProjectController*)aController
{
    NSInteger selectedCappuccinoProject = [self.cappuccinoProjectControllers indexOfObject:aController];
    
    if (selectedCappuccinoProject == -1)
        return;
    
    [self->projectTableView deselectRow:selectedCappuccinoProject];
    [aController cleanUpBeforeDeletion];
    [self.cappuccinoProjectControllers removeObjectAtIndex:selectedCappuccinoProject];
    
    [self _reloadProjectsList];
    
    [self _saveManagedProjectsToUserDefaults];
}


- (void)notifyCappuccinoControllersApplicationIsClosing
{
    [self.cappuccinoProjectControllers makeObjectsPerformSelector:@selector(applicationIsClosing)];
}

- (void)reloadTotalNumberOfErrors
{
    int totalErrors = 0;

    for (XCCCappuccinoProjectController *controller in self.cappuccinoProjectControllers)
        totalErrors += controller.cappuccinoProject.errors.count;

    [self willChangeValueForKey:@"totalNumberOfErrors"];
    self.totalNumberOfErrors = totalErrors;
    [self didChangeValueForKey:@"totalNumberOfErrors"];
}


#pragma mark - Actions

- (IBAction)cleanAllErrors:(id)aSender
{
    [self.cappuccinoProjectControllers makeObjectsPerformSelector:@selector(cleanProjectErrors:) withObject:self];
    [self reloadTotalNumberOfErrors];
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

    [self manageCappuccinoProjectController:[self createNewCappuccinoProjectControllerFromPath:projectPath]];
}

- (IBAction)removeProject:(id)aSender
{
    NSInteger selectedCappuccinoProject = [self->projectTableView selectedRow];
    
    if (selectedCappuccinoProject == -1)
        return;
    
    [self unmanageCappuccinoProjectController:[self.cappuccinoProjectControllers objectAtIndex:selectedCappuccinoProject]];
}

- (IBAction)updateSelectedTab:(id)aSender
{
    self->buttonSelectConfigurationTab.state = NSOffState;
    self->buttonSelectErrorsTab.state = NSOffState;
    self->buttonSelectOperationsTab.state = NSOffState;
    
    if (aSender == self->buttonSelectConfigurationTab)
    {
        self->buttonSelectConfigurationTab.state = NSOnState;
        [self->tabViewProject selectTabViewItemAtIndex:0];
    }
    
    if (aSender == self->buttonSelectErrorsTab)
    {
        self->buttonSelectErrorsTab.state = NSOnState;
        [self->tabViewProject selectTabViewItemAtIndex:1];
    }

    if (aSender == self->buttonSelectOperationsTab)
    {
        self->buttonSelectOperationsTab.state = NSOnState;
        [self->tabViewProject selectTabViewItemAtIndex:2];
    }
}



#pragma mark - SplitView delegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return 300;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex
{
    return 300;
}


#pragma mark - TableView DataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.cappuccinoProjectControllers count];
}

#pragma mark - TableView Delegates

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    XCCCappuccinoProjectControllerDataView  *dataView                    = [tableView makeViewWithIdentifier:@"MainCell" owner:nil];
    XCCCappuccinoProjectController          *cappuccinoProjectController = [self.cappuccinoProjectControllers objectAtIndex:row];
    
    dataView.controller = cappuccinoProjectController;
    
    return dataView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger selectedIndex = [self->projectTableView selectedRow];

    self.currentCappuccinoProjectController                     = (selectedIndex == -1) ? nil : [self.cappuccinoProjectControllers objectAtIndex:selectedIndex];

    self.operationsViewController.cappuccinoProjectController   = self.currentCappuccinoProjectController;
    self.errorsViewController.cappuccinoProjectController       = self.currentCappuccinoProjectController;
    self.settingsViewController.cappuccinoProjectController     = self.currentCappuccinoProjectController;

    [self.operationsViewController reload];
    [self.errorsViewController reload];
    [self.settingsViewController reload];

    [self _showMaskingView:(selectedIndex == -1)];

    [self _saveSelectedProject];

}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowsIndexes toPasteboard:(NSPasteboard*)pasteboard
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowsIndexes];
    [pasteboard declareTypes:[NSArray arrayWithObject:@"projects"] owner:self];
    [pasteboard setData:data forType:@"projects"];
    
    return YES;
}

- (NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *pboard = [info draggingPasteboard];
    
    if ([pboard.types containsObject:(NSString *)NSFilenamesPboardType])
    {
        NSArray *draggedFiles = [pboard propertyListForType:(NSString *)NSFilenamesPboardType];
        
        for (NSString *file in draggedFiles)
        {
            BOOL isDir;
            [[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDir];

            if (!isDir)
                return NSDragOperationNone;
        }
        
        return NSDragOperationCopy;
    }
    else if ([pboard.types containsObject:@"projects"])
    {
        if (operation == NSTableViewDropOn)
            return NSDragOperationNone;
        
        return NSDragOperationMove;
    }
    else
    {
        return NSDragOperationNone;
    }
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
    NSPasteboard *pboard = [info draggingPasteboard];
    
    if ([pboard.types containsObject:(NSString *)NSFilenamesPboardType])
    {
        NSArray *draggedFolders = [pboard propertyListForType:(NSString *)NSFilenamesPboardType];
        
        for (NSString *folder in draggedFolders)
            [self manageCappuccinoProjectController:[self createNewCappuccinoProjectControllerFromPath:folder]];

        return YES;
    }
    else if ([pboard.types containsObject:@"projects"])
    {
        NSData      *rowData    = [pboard dataForType:@"projects"];
        NSIndexSet  *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];

        [self.cappuccinoProjectControllers moveIndexes:rowIndexes toIndex:row];
        [self _reloadProjectsList];
        [self _saveManagedProjectsToUserDefaults];
        
        return YES;
    }
    else
    {
        return NO;
    }
}

@end