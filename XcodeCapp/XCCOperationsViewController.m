//
//  XCCOperationsViewController.m
//  XcodeCapp
//
//  Created by Antoine Mercadal on 6/4/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCOperationsViewController.h"
#import "XCCCappuccinoProjectController.h"
#import "XCCCappuccinoProject.h"
#import "XCCOperationDataView.h"


@implementation XCCOperationsViewController

#pragma nark - Initialization

- (void)viewDidLoad
{
    [super viewDidLoad];
}


#pragma nark - Utilities

- (void)_showMaskingView:(BOOL)shouldShow
{
    if (shouldShow)
    {
        if (self->maskingView.superview)
            return;

        [self->operationTableView setHidden:YES];

        self->maskingView.frame = [self.view bounds];
        [self.view addSubview:self->maskingView positioned:NSWindowAbove relativeTo:nil];
    }
    else
    {
        if (!self->maskingView.superview)
            return;

        [self->operationTableView setHidden:NO];

        [self->maskingView removeFromSuperview];
    }
}

- (void)reload
{
    [self->operationTableView reloadData];

    [self _showMaskingView:!self.cappuccinoProjectController.operations.count];
}


#pragma mark - tableView delegate and datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.cappuccinoProjectController.operations.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
    XCCOperationDataView *datView = [tableView makeViewWithIdentifier:@"OperationDataView" owner:nil];
    [datView setOperation:[self.cappuccinoProjectController.operations objectAtIndex:row]];

    //    [datView.cancelButton setTarget:self];
    //    [datView.cancelButton setAction:@selector(cancelOperation:)];

    return datView;
}

@end
