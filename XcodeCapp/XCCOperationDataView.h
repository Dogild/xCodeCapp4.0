//
//  OperationCellView.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class XCCCSourceProcessingOperation;

@interface XCCOperationDataView : NSTableCellView

@property (nonatomic, retain) IBOutlet NSTextField *fieldDescription;

@property (nonatomic, retain) IBOutlet NSButton *cancelButton;
@property (nonatomic, retain) XCCCSourceProcessingOperation *operation;

@end
