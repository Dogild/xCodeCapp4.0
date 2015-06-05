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
#import "XCCSourcesFinderOperation.h"
#import "XCCSourceProcessingOperation.h"
#import "XCCPPXOperation.h"


@implementation XCCOperationsViewController


#pragma nark - Initialization

- (void)viewDidLoad
{
    [super viewDidLoad];
}


#pragma mark - Notifications

- (void)startListeningToNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self selector:@selector(_didReceiveConversionDidEndNotification:) name:XCCConversionDidEndNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveConversionDidStartNotification:) name:XCCConversionDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveNeedSourceToProjectPathMappingNotification:) name:XCCNeedSourceToProjectPathMappingNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveUpdatePbxFileDidStartNotification:) name:XCCPbxCreationDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveUpdatePbxFileDidEndNotification:) name:XCCPbxCreationDidEndNotification object:nil];
}

- (void)stopListeningToNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center removeObserver:self name:XCCConversionDidEndNotification object:nil];
    [center removeObserver:self name:XCCConversionDidStartNotification object:nil];
    [center removeObserver:self name:XCCNeedSourceToProjectPathMappingNotification object:nil];
    [center removeObserver:self name:XCCPbxCreationDidStartNotification object:nil];
    [center removeObserver:self name:XCCPbxCreationDidEndNotification object:nil];
}

- (BOOL)_doesNotificationBelongToCurrentProject:(NSNotification *)note
{
    return note.userInfo[@"cappuccinoProject"] == self.cappuccinoProjectController.cappuccinoProject;
}

- (void)_didReceiveNeedSourceToProjectPathMappingNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    self.cappuccinoProjectController.cappuccinoProject.projectPathsForSourcePaths[note.userInfo[@"sourcePath"]] = note.userInfo[@"projectPath"];
}

- (void)_didReceiveConversionDidStartNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController operationDidStart:note.object type:note.name userInfo:note.userInfo];
}

- (void)_didReceiveConversionDidEndNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController operationDidEnd:note.object type:note.name userInfo:note.userInfo];
}

- (void)_didReceiveUpdatePbxFileDidStartNotification:(NSNotification*)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController operationDidStart:note.object type:note.name userInfo:note.userInfo];
}

- (void)_didReceiveUpdatePbxFileDidEndNotification:(NSNotification*)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController operationDidEnd:note.object type:note.name userInfo:note.userInfo];
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
