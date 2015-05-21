//
//  OperationViewCell.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ProcessSourceOperation;

@interface OperationViewCell : NSTableCellView

@property (nonatomic, retain) ProcessSourceOperation *operation;

@end
