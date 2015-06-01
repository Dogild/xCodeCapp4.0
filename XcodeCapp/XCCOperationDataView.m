//
//  OperationCellView.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCOperationDataView.h"
#import "XCCCSourceProcessingOperation.h"

@implementation XCCOperationDataView

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow)
    {
        [self.textField bind:@"stringValue" toObject:self.operation withKeyPath:@"operationName" options:nil];
        [self.fieldDescription bind:@"stringValue" toObject:self.operation withKeyPath:@"operationDescription" options:nil];
    }
    else
    {
        [self.textField unbind:@"stringValue"];
        [self.fieldDescription unbind:@"stringValue"];
    }
}

@end