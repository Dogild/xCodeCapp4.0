//
//  OperationErrorCellView.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "OperationErrorCellView.h"
#import "OperationError.h"

@implementation OperationErrorCellView

- (void)setOperationError:(OperationError *)operationError
{
    self.textField.stringValue = operationError.message;
}

@end
