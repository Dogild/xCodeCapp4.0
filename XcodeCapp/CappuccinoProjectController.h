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

@interface CappuccinoProjectController : NSObject

@property CappuccinoProject *cappuccinoProject;

// XcodeCapp is listening the event of this project
@property BOOL isListeningProject;

// Whether we are in the process of loading a project
@property BOOL isLoadingProject;

// Whether we have loaded the project
@property BOOL isProjectLoaded;

// Whether we are currently processing source files
@property BOOL isProcessingProject;

// Full path to pbxprojModifier.py
@property NSString *pbxModifierScriptPath;

// A list of errors generated from the current batch of source processing
@property NSMutableArray *errorList;

// A list of warning generated from the current batch of source processing
@property NSMutableArray *warningList;

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

- (id)initWithPath:(NSString*)aPath;
- (void)loadProject;

- (void)stopListenProject;

@end
