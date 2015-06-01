//
//  MainWindowController.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CappuccinoProject;
@class CappuccinoProjectController;

@interface MainWindowController : NSWindowController <NSSplitViewDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (strong) IBOutlet NSBox          *maskingView;
@property (strong) IBOutlet NSSplitView    *splitView;
@property (strong) IBOutlet NSTableView    *projectTableView;
@property (strong) IBOutlet NSTableView    *operationTableView;
@property (strong) IBOutlet NSOutlineView  *errorOutlineView;
@property (strong) IBOutlet NSView         *projectViewContainer;

@property (strong) NSMutableArray *cappuccinoProjectControllers;
@property (strong) CappuccinoProject *currentCappuccinoProject;

- (IBAction)addProject:(id)aSender;
- (IBAction)removeProject:(id)aSender;
- (IBAction)saveSettings:(id)aSender;
- (IBAction)synchronizeProject:(id)aSender;
- (IBAction)removeErrors:(id)aSender;

- (void)applicationIsClosing;
- (void)addCappuccinoProjectWithPath:(NSString*)aProjectPath;
- (void)_restoreManagedProjectsFromUserDefaults;
- (void)_saveManagedProjectsToUserDefaults;

- (void)reloadErrorsListForCurrentCappuccinoProject;
- (void)reloadOperationsListForCurrentCappuccinoProject;

- (void)removeCappuccinoProject:(CappuccinoProjectController*)aController;

@end
