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


@interface XCCCappuccinoProjectController : NSObject <NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate>
{
    XCCTaskLauncher             *taskLauncher;
    NSOperationQueue            *operationQueue;
    FSEventStreamRef            stream;
    NSNumber                    *lastEventId;
    int                         projectPathFileDescriptor;
    NSMutableDictionary         *pendingPBXOperations;
    NSTimer                     *timerOperationQueueCompletionMonitor;
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

- (IBAction)cancelAllOperations:(id)aSender;
- (IBAction)resetProject:(id)aSender;
- (IBAction)cleanProjectErrors:(id)aSender;
- (IBAction)openProjectInXcode:(id)sender;
- (IBAction)openProjectInFinder:(id)sender;
- (IBAction)openProjectInEditor:(id)sender;
- (IBAction)openProjectInTerminal:(id)sender;
- (IBAction)openRelatedObjjFileInEditor:(id)sender;
- (IBAction)switchProjectListeningStatus:(id)sender;

@end
