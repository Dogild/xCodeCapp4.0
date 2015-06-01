//
//  CappuccinoProjectCellView.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/11/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "XCCCappuccinoProject.h"


@interface XCCCappuccinoProjectDataView : NSTableCellView

@property (nonatomic, retain) IBOutlet NSTextField *pathTextField;
@property (nonatomic, retain) IBOutlet NSButton *loadButton;
@property (nonatomic, retain) IBOutlet NSBox *boxStatus;
@property (nonatomic, retain) XCCCappuccinoProject *cappuccinoProject;

@end