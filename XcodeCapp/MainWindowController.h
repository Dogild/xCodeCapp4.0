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

@property (strong) NSMutableArray *cappuccinoProjectControllers;
@property (strong) CappuccinoProject *currentCappuccinoProject;

- (IBAction)addProject:(id)aSender;
- (IBAction)removeProject:(id)aSender;
- (IBAction)saveSettings:(id)aSender;
- (IBAction)synchronizeProject:(id)aSender;
- (IBAction)removeErrors:(id)aSender;
- (IBAction)stopListeningAllProjects:(id)aSender;

- (void)addProjectPath:(NSString*)aProjectPath;
- (void)pruneProjectHistory;
- (void)fetchProjects;
- (void)saveCurrentProjects;

- (void)reloadErrors;
- (void)reloadOperations;

- (void)unlinkProject:(CappuccinoProjectController*)aController;

@end
