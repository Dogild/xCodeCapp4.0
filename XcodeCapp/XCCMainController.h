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
{
    IBOutlet NSBox                          *maskingView;
    IBOutlet NSSplitView                    *splitView;
    IBOutlet NSTableView                    *projectTableView;
    IBOutlet NSTableView                    *operationTableView;
    IBOutlet NSOutlineView                  *errorOutlineView;
    IBOutlet NSView                         *projectViewContainer;
    IBOutlet NSArrayController              *includePathArrayController;
    IBOutlet NSTabView                      *tabViewProject;
    IBOutlet NSButton                       *buttonSelectConfigurationTab;
    IBOutlet NSButton                       *buttonSelectErrorsTab;
    IBOutlet NSButton                       *buttonSelectOperationsTab;
    IBOutlet NSBox                          *viewErrorsMask;
    IBOutlet NSBox                          *viewOperationMask;
    IBOutlet NSBox                          *viewProjectMask;
    IBOutlet NSView                         *viewTabConfiguration;
    IBOutlet NSView                         *viewTabErrors;
    IBOutlet NSView                         *viewTabOperations;
    BOOL                                    isObserving;
}


@property NSMutableArray                   *cappuccinoProjectControllers;
@property XCCCappuccinoProjectController   *currentCappuccinoProjectController;
@property int                              totalNumberOfErrors;

- (void)addCappuccinoProjectWithPath:(NSString*)aProjectPath;
- (void)removeCappuccinoProject:(XCCCappuccinoProjectController*)aController;
- (void)reloadCurrentProjectErrors;
- (void)reloadCurrentProjectOperations;
- (void)reloadTotalNumberOfErrors;
- (void)saveManagedProjectsToUserDefaults;
- (void)notifyCappuccinoControllersApplicationIsClosing;

- (IBAction)addProject:(id)aSender;
- (IBAction)removeProject:(id)aSender;
- (IBAction)updateSelectedTab:(id)aSender;
- (IBAction)cleanSelectedProjectErrors:(id)aSender;
- (IBAction)cleanAllErrors:(id)aSender;

@end
