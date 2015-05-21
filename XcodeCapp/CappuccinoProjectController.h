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

@interface CappuccinoProjectController : NSObject <NSTableViewDataSource, NSTableViewDelegate>

@property CappuccinoProject *cappuccinoProject;

// Full path to pbxprojModifier.py
@property NSString *pbxModifierScriptPath;

// A list of files currently processing
@property NSMutableArray *currentOperations;

// Coalesces the modifications that have to be made to the Xcode project
// after changes are made to source files. Keys are the actions "add" or "remove",
// values are arrays of full paths to source files that need to be added or removed.
@property NSMutableDictionary *pbxOperations;

// The last FSEvent id we received. This is stored in the user prefs
// so we can get all changes since the last time XcodeCapp was launched.
@property NSNumber *lastEventId;

// Task manager of the project
@property TaskManager *taskManager;

@property NSTableView *operationsTableView;

- (id)initWithPath:(NSString*)aPath;
- (void)loadProject;

- (void)stopListenProject;
- (void)startListenProject;

- (IBAction)save:(id)sender;

@end
