//
//  CappuccinoProjectController.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/7/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XCCCappuccinoProject;
@class XCCTaskLauncher;
@class XCCMainController;

extern NSString * const XCCStartListeningProjectNotification;
extern NSString * const XCCStopListeningProjectNotification;

@interface XCCCappuccinoProjectController : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate>

@property XCCCappuccinoProject *cappuccinoProject;
@property XCCMainController *mainWindowController;

// Task manager of the project
@property XCCTaskLauncher *taskLauncher;

- (id)initWithPath:(NSString*)aPath controller:(id)aController;

- (void)applicationIsClosing;
- (void)cleanUpBeforeDeletion;

- (IBAction)save:(id)sender;
- (IBAction)cancelAllOperations:(id)aSender;
- (IBAction)synchronizeProject:(id)aSender;
- (IBAction)removeErrors:(id)aSender;
- (IBAction)openXcodeProject:(id)sender;

- (void)openObjjFile:(id)sender;

- (IBAction)switchProjectListeningStatus:(id)sender;

@end
