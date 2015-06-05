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
        [self _updateDataView];
        [self.operation addObserver:self forKeyPath:@"operationName" options:NSKeyValueObservingOptionNew context:nil];
        [self.operation addObserver:self forKeyPath:@"operationDescription" options:NSKeyValueObservingOptionNew context:nil];
        [self.operation addObserver:self forKeyPath:@"isExecuting" options:NSKeyValueObservingOptionNew context:nil];
    }
    else
    {
        [self.operation removeObserver:self forKeyPath:@"operationName"];
        [self.operation removeObserver:self forKeyPath:@"operationDescription"];
        [self.operation removeObserver:self forKeyPath:@"isExecuting"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(XCCSourceProcessingOperation *)operation change:(NSDictionary *)change context:(void *)context
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self _updateDataView];
    });
}

- (void)_updateDataView
{
    self->fieldName.stringValue         = self.operation.operationName;
    self->fieldDescription.stringValue  = self.operation.operationDescription;
    self->boxStatus.fillColor           = self.operation.isExecuting ? [NSColor greenColor] : [NSColor grayColor];
}

@end


