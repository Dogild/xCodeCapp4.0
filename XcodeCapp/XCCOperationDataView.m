//
//  OperationCellView.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCOperationDataView.h"
#import "XCCSourceProcessingOperation.h"

@implementation XCCOperationDataView

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow)
    {
        [self->fieldName bind:@"stringValue" toObject:self.operation withKeyPath:@"operationName" options:nil];
        [self->fieldDescription bind:@"stringValue" toObject:self.operation withKeyPath:@"operationDescription" options:nil];
    }
    else
    {
        [self->fieldName unbind:@"stringValue"];
        [self->fieldDescription unbind:@"stringValue"];
    }
}

@end
