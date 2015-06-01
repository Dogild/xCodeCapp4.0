//
//  OperationErrorCellView.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCOperationErrorDataView.h"
#import "XCCOperationError.h"

@implementation XCCOperationErrorDataView

- (void)setOperationError:(XCCOperationError *)operationError
{
    self.textField.stringValue = operationError.message;
    self.fieldLineNumber.stringValue = operationError.lineNumber;
}

@end