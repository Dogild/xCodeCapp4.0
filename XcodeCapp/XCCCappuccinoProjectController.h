//
//  CappuccinoProjectController.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/7/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class XCCAbstractOperation;
@class XCCCappuccinoProject;
@class XCCTaskLauncher;
@class XCCMainController;


@interface XCCCappuccinoProjectController : NSObject
{
    XCCTaskLauncher             *taskLauncher;
    NSOperationQueue            *operationQueue;
    FSEventStreamRef            stream;
    int                         projectPathFileDescriptor;
    NSMutableDictionary         *pendingPBXOperations;
    NSTimer                     *timerOperationQueueCompletionMonitor;
    NSMutableDictionary         *sourceProcessingOperations;
}

@property NSInteger             operationsTotal;
@property NSInteger             operationsComplete;
@property CGFloat               operationsProgress;
@property NSMutableArray        *operations;
@property XCCCappuccinoProject  *cappuccinoProject;
@property XCCMainController     *mainXcodeCappController;


- (id)initWithPath:(NSString*)aPath controller:(id)aController;
- (void)reinitializeProjectFromSettings;
- (void)applicationIsClosing;
- (void)cleanUpBeforeDeletion;
- (void)operationDidStart:(XCCAbstractOperation*)anOperation type:(NSString*)aType userInfo:(NSDictionary*)userInfo;
- (void)operationDidEnd:(XCCAbstractOperation*)anOperation type:(NSString*)aType userInfo:(NSDictionary*)userInfo;
- (void)launchEditorForPath:(NSString*)path line:(NSInteger)line;

- (IBAction)cancelAllOperations:(id)aSender;
- (IBAction)resetProject:(id)aSender;
- (IBAction)openProjectInXcode:(id)sender;
- (IBAction)openProjectInFinder:(id)sender;
- (IBAction)openProjectInEditor:(id)sender;
- (IBAction)openProjectInTerminal:(id)sender;
- (IBAction)switchProjectListeningStatus:(id)sender;

@end
