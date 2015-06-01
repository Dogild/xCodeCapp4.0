//
//  OperationErrorCellView.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class XCCOperationError;

@interface XCCOperationErrorDataView : NSTableCellView

@property (nonatomic, retain) XCCOperationError *operationError;

@property (nonatomic, retain) IBOutlet NSTextField *fieldLineNumber;
@property (nonatomic, retain) IBOutlet NSTextField *labelLineNumber;
@property (nonatomic, retain) IBOutlet NSBox *boxErrorContent;

@end
