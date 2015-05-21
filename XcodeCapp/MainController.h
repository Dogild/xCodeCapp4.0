//
//  MainController.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CappuccinoProject;

@interface MainController : NSObject <NSSplitViewDelegate, NSTableViewDataSource, NSTableViewDelegate>

@property (strong) IBOutlet NSSplitView    *splitView;
@property (strong) IBOutlet NSTableView    *projectTableView;
@property (strong) IBOutlet NSTableView    *operationTableView;
@property (strong) IBOutlet NSTableView    *errorTableView;
@property (strong) IBOutlet NSTableView    *warningTableView;

@property (strong) NSMutableArray *cappuccinoProjectController;
@property (strong) CappuccinoProject *currentCappuccinoProject;

- (IBAction)addProject:(id)aSender;
- (IBAction)removeProject:(id)aSender;
- (IBAction)saveSettings:(id)aSender;
- (IBAction)synchronizeProject:(id)aSender;

- (void)addProjectPath:(NSString*)aProjectPath;
- (void)pruneProjectHistory;
- (void)fetchProjects;

- (void)applicationWillTerminate:(NSNotification *)aNotification;

@end
