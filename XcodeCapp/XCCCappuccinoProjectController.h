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

@property XCCCappuccinoProject  *cappuccinoProject;
@property XCCMainController     *mainWindowController;
@property XCCTaskLauncher       *taskLauncher;
@property NSOperationQueue      *operationQueue;
@property CGFloat               operationsProgress;
@property NSInteger             operationsTotal;
@property NSInteger             operationsComplete;


- (id)initWithPath:(NSString*)aPath controller:(id)aController;
- (void)reinitializeProjectFromSettings;
- (void)applicationIsClosing;
- (void)cleanUpBeforeDeletion;

- (IBAction)cancelAllOperations:(id)aSender;
- (IBAction)resetProject:(id)aSender;
- (IBAction)removeErrors:(id)aSender;
- (IBAction)openXcodeProject:(id)sender;

- (void)openObjjFile:(id)sender;

- (IBAction)switchProjectListeningStatus:(id)sender;

@end
