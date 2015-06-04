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
@class XCCOperationsViewController;
@class XCCErrorsViewController;


@interface XCCMainController : NSWindowController <NSSplitViewDelegate, NSTableViewDataSource, NSTableViewDelegate>
{
    IBOutlet NSBox                          *maskingView;
    IBOutlet NSSplitView                    *splitView;
    IBOutlet NSTableView                    *projectTableView;
    IBOutlet NSView                         *projectViewContainer;
    IBOutlet NSArrayController              *includePathArrayController;
    IBOutlet NSTabView                      *tabViewProject;
    IBOutlet NSButton                       *buttonSelectConfigurationTab;
    IBOutlet NSButton                       *buttonSelectErrorsTab;
    IBOutlet NSButton                       *buttonSelectOperationsTab;
    IBOutlet NSBox                          *viewProjectMask;
    IBOutlet NSView                         *viewTabConfiguration;
    BOOL                                    isObserving;
}

@property IBOutlet XCCOperationsViewController  *operationsViewController;
@property IBOutlet XCCErrorsViewController      *errorsViewController;
@property NSMutableArray                        *cappuccinoProjectControllers;
@property XCCCappuccinoProjectController        *currentCappuccinoProjectController;
@property int                                   totalNumberOfErrors;

- (void)addCappuccinoProjectWithPath:(NSString*)aProjectPath;
- (void)removeCappuccinoProject:(XCCCappuccinoProjectController*)aController;
- (void)reloadTotalNumberOfErrors;
- (void)reloadProjectsList;
- (void)saveManagedProjectsToUserDefaults;
- (void)notifyCappuccinoControllersApplicationIsClosing;

- (IBAction)addProject:(id)aSender;
- (IBAction)removeProject:(id)aSender;
- (IBAction)updateSelectedTab:(id)aSender;
- (IBAction)cleanSelectedProjectErrors:(id)aSender;
- (IBAction)cleanAllErrors:(id)aSender;

@end
