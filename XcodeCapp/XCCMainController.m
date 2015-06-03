//
//  MainWindowController.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCMainController.h"
#import "XCCCappuccinoProject.h"
#import "XCCCappuccinoProjectController.h"
#import "XCCCappuccinoProjectControllerDataView.h"
#import "CappuccinoUtils.h"
#import "UserDefaults.h"

@interface XCCMainController()
@property BOOL _isObserving;
@end

@implementation XCCMainController


#pragma mark - Initialization

- (void)windowDidLoad
{
    [self _showMaskingView:YES];
    [self _showProjectsTableMaskingView:YES];
    [self _showErrorsTableMaskingView:YES];
    [self _showOperationsTableMaskingView:YES];
    
    [self _restoreManagedProjectsFromUserDefaults];
    [self _selectLastProjectSelected];
    
    NSTabViewItem *itemConfiguration = [[NSTabViewItem alloc] initWithIdentifier:@"configuration"];
    [itemConfiguration setView:self.viewTabConfiguration];
    [self.tabViewProject addTabViewItem:itemConfiguration];
    
    NSTabViewItem *itemErrors = [[NSTabViewItem alloc] initWithIdentifier:@"errors"];
    [itemErrors setView:self.viewTabErrors];
    [self.tabViewProject addTabViewItem:itemErrors];
    
    NSTabViewItem *itemOperations = [[NSTabViewItem alloc] initWithIdentifier:@"operations"];
    [itemOperations setView:self.viewTabOperations];
    [self.tabViewProject addTabViewItem:itemOperations];
    
    NSMutableParagraphStyle *paragraphStyle= [NSMutableParagraphStyle new];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
    
    NSDictionary *attrs = @{NSFontAttributeName: [NSFont systemFontOfSize:11],
                            NSForegroundColorAttributeName: [NSColor whiteColor],
                            NSParagraphStyleAttributeName: paragraphStyle};
    
    self.buttonSelectConfigurationTab.attributedTitle = [[NSMutableAttributedString alloc] initWithString:self.buttonSelectConfigurationTab.title attributes:attrs];
    self.buttonSelectErrorsTab.attributedTitle = [[NSMutableAttributedString alloc] initWithString:self.buttonSelectErrorsTab.title attributes:attrs];
    self.buttonSelectOperationsTab.attributedTitle = [[NSMutableAttributedString alloc] initWithString:self.buttonSelectOperationsTab.title attributes:attrs];
    
    [self updateSelectedTab:self.buttonSelectConfigurationTab];
    
    [self.projectTableView registerForDraggedTypes:[NSArray arrayWithObjects:@"projects", NSFilenamesPboardType, nil]];
}


#pragma mark - Array Controller Observers

- (void)_addArrayControllerObserver
{
    if (self._isObserving)
        return;
    
    self._isObserving = YES;
    
    [self.includePathArrayController addObserver:self forKeyPath:@"arrangedObjects.name" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)_removeArrayControllerObserver
{
    if (!self._isObserving)
        return;
    
    self._isObserving = NO;
    
    [self.includePathArrayController removeObserver:self forKeyPath:@"arrangedObjects.name"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (!self.currentCappuccinoProjectController)
        return;
    
    if (self.currentCappuccinoProjectController.cappuccinoProject.status != XCCCappuccinoProjectStatusListening)
        return;
    
    [self.currentCappuccinoProjectController reinitializeProjectFromSettings];
}


#pragma mark - Utilities


- (void)_showMaskingView:(BOOL)shouldShow
{
    if (shouldShow)
    {
        if (self.maskingView.superview)
            return;
        
        [self.projectViewContainer setHidden:YES];
        
        self.maskingView.frame = [[[self.splitView subviews] objectAtIndex:1] bounds];
        [[[self.splitView subviews] objectAtIndex:1] addSubview:self.maskingView positioned:NSWindowAbove relativeTo:nil];
    }
    else
    {
        if (!self.maskingView.superview)
            return;
        
        [self.projectViewContainer setHidden:NO];
        
        [self.maskingView removeFromSuperview];
    }
}

- (void)_showErrorsTableMaskingView:(BOOL)shouldShow
{
    if (shouldShow)
    {
        if (self.viewErrorsMask.superview)
            return;
        
        [self.errorOutlineView setHidden:YES];
        
        self.viewErrorsMask.frame = [self.viewTabErrors bounds];
        [self.viewTabErrors addSubview:self.viewErrorsMask positioned:NSWindowAbove relativeTo:nil];
    }
    else
    {
        if (!self.viewErrorsMask.superview)
            return;
        
        [self.errorOutlineView setHidden:NO];
        
        [self.viewErrorsMask removeFromSuperview];
    }
}

- (void)_showOperationsTableMaskingView:(BOOL)shouldShow
{
    if (shouldShow)
    {
        if (self.viewOperationMask.superview)
            return;
        
        [self.operationTableView setHidden:YES];
        
        self.viewOperationMask.frame = [self.viewTabOperations bounds];
        [self.viewTabOperations addSubview:self.viewOperationMask positioned:NSWindowAbove relativeTo:nil];
    }
    else
    {
        if (!self.viewOperationMask.superview)
            return;
        
        [self.operationTableView setHidden:NO];
        
        [self.viewOperationMask removeFromSuperview];
    }
}

- (void)_showProjectsTableMaskingView:(BOOL)shouldShow
{
    if (shouldShow)
    {
        if (self.viewProjectMask.superview)
            return;
        
        [self.projectTableView setHidden:YES];
        
        self.viewProjectMask.frame = [self.splitView.superview bounds];
        [self.splitView.superview addSubview:self.viewProjectMask positioned:NSWindowAbove relativeTo:nil];
    }
    else
    {
        if (!self.viewProjectMask.superview)
            return;
        
        [self.projectTableView setHidden:NO];
        
        [self.viewProjectMask removeFromSuperview];
    }
}


#pragma mark - Application Lifecycle

- (void)notifyCappuccinoControllersApplicationIsClosing
{
    [self.cappuccinoProjectControllers makeObjectsPerformSelector:@selector(applicationIsClosing)];
}


#pragma mark - Projects history

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
        
        [self.projectTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:indexToSelect] byExtendingSelection:NO];
    }

    
    DDLogVerbose(@"Stop : selecting last selected project");
}

- (void)_restoreManagedProjectsFromUserDefaults
{
    DDLogVerbose(@"Start : restore managed projects");
    self.cappuccinoProjectControllers = [NSMutableArray new];
    
    NSArray *projectHistory = [[NSUserDefaults standardUserDefaults] arrayForKey:kDefaultXCCCurrentManagedProjects];
    
    for (NSString *path in projectHistory)
    {
        XCCCappuccinoProjectController *cappuccinoProjectController = [[XCCCappuccinoProjectController alloc] initWithPath:path controller:self];
        [self.cappuccinoProjectControllers addObject:cappuccinoProjectController];
    }
    
    [self reloadProjectsList];
    
    DDLogVerbose(@"Stop : managed  projects restored");
}

- (void)_saveManagedProjectsToUserDefaults
{
    NSMutableArray *historyProjectPaths = [NSMutableArray array];
    
    for (XCCCappuccinoProjectController *controller in self.cappuccinoProjectControllers)
        [historyProjectPaths addObject:controller.cappuccinoProject.projectPath];
    
    [[NSUserDefaults standardUserDefaults] setObject:historyProjectPaths forKey:kDefaultXCCCurrentManagedProjects];
}


#pragma mark - Public Utilities

- (void)removeCappuccinoProject:(XCCCappuccinoProjectController*)aController
{
    NSInteger selectedCappuccinoProject = [self.cappuccinoProjectControllers indexOfObject:aController];
    
    if (selectedCappuccinoProject == -1)
        return;
    
    [self.projectTableView deselectRow:selectedCappuccinoProject];
    [aController cleanUpBeforeDeletion];
    [self.cappuccinoProjectControllers removeObjectAtIndex:selectedCappuccinoProject];
    
    [self reloadProjectsList];
    
    [self _saveManagedProjectsToUserDefaults];
}

- (void)addCappuccinoProjectWithPath:(NSString*)aProjectPath
{
    if ([[self.cappuccinoProjectControllers filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"cappuccinoProject.projectPath == %@", aProjectPath]] count])
    {
        NSRunAlertPanel(@"This project is already managed.", @"Please remove the other project or use the reset button.", @"OK", nil, nil, nil);
        return;
    }
    XCCCappuccinoProjectController *cappuccinoProjectController = [[XCCCappuccinoProjectController alloc] initWithPath:aProjectPath controller:self];

    [self.cappuccinoProjectControllers addObject:cappuccinoProjectController];
    
    NSInteger index = [self.cappuccinoProjectControllers indexOfObject:cappuccinoProjectController];

    [self reloadProjectsList];
    
    [self.projectTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
    [self.projectTableView scrollRowToVisible:index];
    [self _saveManagedProjectsToUserDefaults];
}

- (void)reloadErrorsListForCurrentCappuccinoProject
{
    [self.errorOutlineView reloadData];
    [self.errorOutlineView expandItem:nil expandChildren:YES];
    
    if (!self.currentCappuccinoProjectController.cappuccinoProject.errors.count)
        [self _showErrorsTableMaskingView:YES];
    else
        [self _showErrorsTableMaskingView:NO];
}

- (void)reloadOperationsListForCurrentCappuccinoProject
{
    [self.operationTableView reloadData];
    
    if (!self.currentCappuccinoProjectController.operations.count)
        [self _showOperationsTableMaskingView:YES];
    else
        [self _showOperationsTableMaskingView:NO];
}

- (void)reloadProjectsList
{
    [self.projectTableView reloadData];
    
    if (self.cappuccinoProjectControllers.count == 0)
        [self _showProjectsTableMaskingView:YES];
    else
        [self _showProjectsTableMaskingView:NO];

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

- (IBAction)updateSelectedTab:(id)aSender
{
    self.buttonSelectConfigurationTab.state = NSOffState;
    self.buttonSelectErrorsTab.state = NSOffState;
    self.buttonSelectOperationsTab.state = NSOffState;
    
    if (aSender == self.buttonSelectConfigurationTab)
    {
        self.buttonSelectConfigurationTab.state = NSOnState;
        [self.tabViewProject selectTabViewItemAtIndex:0];
    }
    
    if (aSender == self.buttonSelectErrorsTab)
    {
        self.buttonSelectErrorsTab.state = NSOnState;
        [self.tabViewProject selectTabViewItemAtIndex:1];
    }

    if (aSender == self.buttonSelectOperationsTab)
    {
        self.buttonSelectOperationsTab.state = NSOnState;
        [self.tabViewProject selectTabViewItemAtIndex:2];
    }
}

- (IBAction)cleanAllErrors:(id)aSender
{
    [self.currentCappuccinoProjectController removeErrors:aSender];
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


#pragma mark - TableView delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return [self.cappuccinoProjectControllers count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    XCCCappuccinoProjectControllerDataView  *dataView                    = [tableView makeViewWithIdentifier:@"MainCell" owner:nil];
    XCCCappuccinoProjectController          *cappuccinoProjectController = [self.cappuccinoProjectControllers objectAtIndex:row];
    
    dataView.controller = cappuccinoProjectController;
    
    return dataView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification
{
    NSInteger selectedCappuccinoProject = [self.projectTableView selectedRow];
    
    [self _removeArrayControllerObserver];
    
    if (selectedCappuccinoProject == -1)
    {
        self.currentCappuccinoProjectController = nil;
        [self.operationTableView setDelegate:nil];
        [self.operationTableView setDataSource:nil];

        [self _showMaskingView:YES];
        [[NSUserDefaults standardUserDefaults] setObject:@"" forKey:kDefaultXCCLastSelectedProjectPath];
        return;
    }
    
    self.currentCappuccinoProjectController = [self.cappuccinoProjectControllers objectAtIndex:selectedCappuccinoProject];
    
    [self.operationTableView setDelegate:self.currentCappuccinoProjectController];
    [self.operationTableView setDataSource:self.currentCappuccinoProjectController];
    
    [self.errorOutlineView setDelegate:self.currentCappuccinoProjectController];
    [self.errorOutlineView setDataSource:self.currentCappuccinoProjectController];
    [self.errorOutlineView setDoubleAction:@selector(openObjjFile:)];
    [self.errorOutlineView setTarget:self.currentCappuccinoProjectController];
    
    [self _addArrayControllerObserver];
    
    [self _showMaskingView:NO];
    [[NSUserDefaults standardUserDefaults] setObject:self.currentCappuccinoProjectController.cappuccinoProject.projectPath forKey:kDefaultXCCLastSelectedProjectPath];
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
        
        for (NSString *folders in draggedFolders)
            [self addCappuccinoProjectWithPath:folders];

        return YES;
    }
    else if ([pboard.types containsObject:@"projects"])
    {
        NSData      *rowData    = [pboard dataForType:@"projects"];
        NSIndexSet  *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];

        [self.cappuccinoProjectControllers moveIndexes:rowIndexes toIndex:row];
        [self reloadProjectsList];
        [self _saveManagedProjectsToUserDefaults];
        
        return YES;
    }
    else
    {
        return NO;
    }
}

@end
