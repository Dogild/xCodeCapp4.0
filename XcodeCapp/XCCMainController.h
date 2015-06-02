//
//  MainWindowController.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSMutableArray+moveIndexes.h"

@class XCCCappuccinoProject;
@class XCCCappuccinoProjectController;

@interface XCCMainController : NSWindowController <NSSplitViewDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (strong) IBOutlet NSBox                   *maskingView;
@property (strong) IBOutlet NSSplitView             *splitView;
@property (strong) IBOutlet NSTableView             *projectTableView;
@property (strong) IBOutlet NSTableView             *operationTableView;
@property (strong) IBOutlet NSOutlineView           *errorOutlineView;
@property (strong) IBOutlet NSView                  *projectViewContainer;
@property (strong) IBOutlet NSArrayController       *includePathArrayController;
@property (strong) IBOutlet NSTabView               *tabViewProject;
@property (strong) IBOutlet NSButton                *buttonSelectConfigurationTab;
@property (strong) IBOutlet NSButton                *buttonSelectErrorsTab;
@property (strong) IBOutlet NSButton                *buttonSelectOperationsTab;

@property (strong) IBOutlet NSView                  *viewTabConfiguration;
@property (strong) IBOutlet NSView                  *viewTabErrors;
@property (strong) IBOutlet NSView                  *viewTabOperations;

@property (strong) NSMutableArray                   *cappuccinoProjectControllers;
@property (strong) XCCCappuccinoProject             *currentCappuccinoProject;
@property (strong) XCCCappuccinoProjectController   *currentCappuccinoProjectController;

- (IBAction)addProject:(id)aSender;
- (IBAction)removeProject:(id)aSender;
- (IBAction)updateSelectedTab:(id)aSender;

- (void)notifyCappuccinoControllersApplicationIsClosing;
- (void)addCappuccinoProjectWithPath:(NSString*)aProjectPath;
- (void)_restoreManagedProjectsFromUserDefaults;
- (void)_saveManagedProjectsToUserDefaults;

- (void)reloadErrorsListForCurrentCappuccinoProject;
- (void)reloadOperationsListForCurrentCappuccinoProject;

- (void)removeCappuccinoProject:(XCCCappuccinoProjectController*)aController;

@end
