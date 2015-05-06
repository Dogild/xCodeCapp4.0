//
//  CappuccinoProject.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CappuccinoProject : NSObject
{
    
}

// XcodeCapp is listening the event of this project
@property BOOL isListeningProject;

// Whether we are in the process of loading a project
@property BOOL isLoadingProject;

// Whether we are currently processing source files
@property BOOL isProcessingProject;

// Full path to .XcodeSupport
@property NSString *supportPath;

// Full path to the Cappuccino project root directory
@property NSString *projectPath;

// Full path to the <project>.xcodeproj
@property NSString *xcodeProjectPath;

// Full path to parser.j
@property NSString *parserPath;

// Full path to pbxprojModifier.py
@property NSString *pbxModifierScriptPath;

// Full path to .XcodeSupport/Info.plist
@property NSString *infoPlistPath;

// Environment paths used by this project
@property NSArray *environementsPaths;

// A mapping from full paths to project-relative paths
@property NSMutableDictionary *projectPathsForSourcePaths;

// A list of files name who can be processed, based on xcapp-ignore and path pf the project
@property NSMutableArray *xCodeCappTargetedFiles;

// A list of errors generated from the current batch of source processing
@property NSMutableArray *errorList;

// A list of warning generated from the current batch of source processing
@property NSMutableArray *warningList;

// A list of files currently processing
@property NSMutableArray *processingFilesList;

- (id)initWithPath:(NSString*)aPath;
- (void)loadProject;
- (void)startListenProject;
- (void)stopListenProject;

@end
