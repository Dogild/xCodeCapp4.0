//
//  OperationViewCell.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "OperationViewCell.h"
#import "ProcessSourceOperation.h"

@implementation OperationViewCell

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow)
    {
        [self.textField bind:@"stringValue" toObject:self.operation withKeyPath:@"description" options:nil];
    }
    else
    {
        [self.textField unbind:@"stringValue"];
    }
}
@end
