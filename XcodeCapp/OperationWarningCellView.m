//
//  OperationWarningCellView.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "OperationWarningCellView.h"
#import "OperationError.h"

@implementation OperationWarningCellView

- (void)setOperationError:(OperationError *)operationError
{
    self.textField.stringValue = operationError.message;
}

@end
