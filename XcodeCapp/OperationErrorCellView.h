//
//  OperationErrorCellView.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/21/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class OperationError;

@interface OperationErrorCellView : NSTableCellView

@property (nonatomic, retain) OperationError *operationError;

@end
