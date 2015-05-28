//
//  CappuccinoProjectController.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/7/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CappuccinoProject;
@class TaskManager;
@class MainWindowController;

extern NSString * const XCCStartListeningProjectNotification;
extern NSString * const XCCStopListeningProjectNotification;

@interface CappuccinoProjectController : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate>

@property CappuccinoProject *cappuccinoProject;
@property MainWindowController *mainWindowController;

// Task manager of the project
@property TaskManager *taskManager;

- (id)initWithPath:(NSString*)aPath;
- (void)loadProject;

- (void)stopListenProject;
- (void)startListenProject;

- (void)removeXcodeProject;
- (void)removeXcodeSupportDirectory;

- (IBAction)save:(id)sender;
- (IBAction)cancelAllOperations:(id)aSender;
- (IBAction)synchronizeProject:(id)aSender;
- (IBAction)removeErrors:(id)aSender;
- (IBAction)openXcodeProject:(id)sender;

- (void)openObjjFile:(id)sender;

@end
