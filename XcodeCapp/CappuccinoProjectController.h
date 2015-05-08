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

// Whether we are currently processing source files
@property BOOL isProcessingProject;

// Full path to parser.j
@property NSString *parserPath;

// Full path to pbxprojModifier.py
@property NSString *pbxModifierScriptPath;

// A list of errors generated from the current batch of source processing
@property NSMutableArray *errorList;

// A list of warning generated from the current batch of source processing
@property NSMutableArray *warningList;

// A list of files currently processing
@property NSMutableArray *currentOperations;

// Task manager of the project
@property TaskManager *taskManager;

@end
