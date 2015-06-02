//
//  CappuccinoProjectCellView.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/11/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XCCCappuccinoProjectController.h"


@interface XCCCappuccinoProjectControllerDataView : NSTableCellView

@property (nonatomic, retain) IBOutlet NSTextField                  *pathTextField;
@property (nonatomic, retain) IBOutlet NSButton                     *buttonSwitchStatus;
@property (nonatomic, retain) IBOutlet NSButton                     *buttonOpenXcodeProject;
@property (nonatomic, retain) IBOutlet NSButton                     *buttonResetProject;
@property (nonatomic, retain) IBOutlet NSButton                     *buttonOpenInFinder;
@property (nonatomic, retain) IBOutlet NSButton                     *buttonOpenInEditor;
@property (nonatomic, retain) IBOutlet NSButton                     *buttonOpenInTerminal;
@property (nonatomic, retain) IBOutlet NSBox                        *boxStatus;
@property (nonatomic, retain) IBOutlet NSProgressIndicator          *operationsProgressIndicator;

@property (nonatomic, retain) XCCCappuccinoProjectController        *controller;


@end
