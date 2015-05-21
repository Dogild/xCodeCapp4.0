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
@class MainController;

@interface CappuccinoProjectController : NSObject <NSTableViewDataSource, NSTableViewDelegate>

@property CappuccinoProject *cappuccinoProject;

// Task manager of the project
@property TaskManager *taskManager;

// Task manager of the project
@property MainController *mainController;

- (id)initWithPath:(NSString*)aPath;
- (void)loadProject;

- (void)stopListenProject;
- (void)startListenProject;

- (IBAction)save:(id)sender;
- (IBAction)cancelAllOperations:(id)aSender;

@end
