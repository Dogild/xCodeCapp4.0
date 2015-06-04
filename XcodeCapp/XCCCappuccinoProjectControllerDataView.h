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
{
    IBOutlet NSTextField                    *fieldNickname;
    IBOutlet NSTextField                    *fieldPath;
    IBOutlet NSButton                       *buttonSwitchStatus;
    IBOutlet NSButton                       *buttonOpenXcodeProject;
    IBOutlet NSButton                       *buttonResetProject;
    IBOutlet NSButton                       *buttonOpenInFinder;
    IBOutlet NSButton                       *buttonOpenInEditor;
    IBOutlet NSButton                       *buttonOpenInTerminal;
    IBOutlet NSBox                          *boxStatus;
    IBOutlet NSProgressIndicator            *operationsProgressIndicator;
    IBOutlet NSProgressIndicator            *waitingProgressIndicator;
}

@property XCCCappuccinoProjectController    *controller;

@end
