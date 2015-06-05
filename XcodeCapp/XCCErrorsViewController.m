//
//  XCCErrorsViewController.m
//  XcodeCapp
//
//  Created by Antoine Mercadal on 6/4/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "CappLintUtils.h"
#import "ObjjUtils.h"
#import "XCCErrorsViewController.h"
#import "XCCCappuccinoProjectController.h"
#import "XCCCappuccinoProject.h"
#import "XCCOperationErrorDataView.h"
#import "XCCOperationErrorHeaderDataView.h"
#import "XCCMainController.h"
#import "XCCSourceProcessingOperation.h"

@implementation XCCErrorsViewController


#pragma mark - Initialization

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self->errorOutlineView setTarget:self];
    [self->errorOutlineView setDoubleAction:@selector(openErroredFileInEditor:)];
}

#pragma mark - Notifications

- (void)startListeningToNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center addObserver:self selector:@selector(_didReceiveConversionDidGenerateErrorNotification:) name:XCCConversionDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveCappLintDidGenerateErrorNotification:) name:XCCCappLintDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveCappLintDidStartNotification:) name:XCCCappLintDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveNib2CibDidGenerateErrorNotification:) name:XCCNib2CibDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveNib2CibDidStartNotifcation:) name:XCCNib2CibDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveObjj2ObjcSeleketonDidGenerateErrorNotification:) name:XCCObjj2ObjcSkeletonDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveObjj2ObjcSkeletonDidStartNotification:) name:XCCObjj2ObjcSkeletonDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveObjjDidGenerateErrorNotification:) name:XCCObjjDidGenerateErrorNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveObjjDidStartNotification:) name:XCCObjjDidStartNotification object:nil];
    [center addObserver:self selector:@selector(_didReceiveConversionDidEndNotification:) name:XCCConversionDidEndNotification object:nil];
}

- (void)stopListeningToNotifications
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    [center removeObserver:self name:XCCCappLintDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCCappLintDidStartNotification object:nil];
    [center removeObserver:self name:XCCConversionDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCNib2CibDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCNib2CibDidStartNotification object:nil];
    [center removeObserver:self name:XCCObjj2ObjcSkeletonDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCObjj2ObjcSkeletonDidStartNotification object:nil];
    [center removeObserver:self name:XCCObjjDidGenerateErrorNotification object:nil];
    [center removeObserver:self name:XCCObjjDidStartNotification object:nil];
    [center removeObserver:self name:XCCConversionDidEndNotification object:nil];
}

- (BOOL)_doesNotificationBelongToCurrentProject:(NSNotification *)note
{
    return note.userInfo[@"cappuccinoProject"] == self.cappuccinoProjectController.cappuccinoProject;
}

- (void)_didReceiveObjj2ObjcSkeletonDidStartNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController.cappuccinoProject removeOperationErrorsRelatedToSourcePath:note.userInfo[@"sourcePath"] errorType:XCCObjj2ObjcSkeletonOperationErrorType];
    [self reload];
}

- (void)_didReceiveObjjDidStartNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController.cappuccinoProject removeOperationErrorsRelatedToSourcePath:note.userInfo[@"sourcePath"] errorType:XCCObjjOperationErrorType];
    [self reload];
}

- (void)_didReceiveNib2CibDidStartNotifcation:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController.cappuccinoProject removeOperationErrorsRelatedToSourcePath:note.userInfo[@"sourcePath"] errorType:XCCNib2CibOperationErrorType];
    [self reload];
}

- (void)_didReceiveCappLintDidStartNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController.cappuccinoProject removeOperationErrorsRelatedToSourcePath:note.userInfo[@"sourcePath"] errorType:XCCCappLintOperationErrorType];
    [self reload];
}

- (void)_didReceiveConversionDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController.cappuccinoProject addOperationError:[XCCOperationError defaultOperationErrorFromDictionary:note.userInfo]];
    [self reload];
    
    [CappuccinoUtils notifyUserWithTitle:self.cappuccinoProjectController.cappuccinoProject.nickname
                                 message:[NSString stringWithFormat:@"Unknown Error: %@", [note.userInfo[@"sourcePath"] lastPathComponent]]];
}

- (void)_didReceiveObjj2ObjcSeleketonDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    for (XCCOperationError *operationError in [ObjjUtils operationErrorsFromDictionary:note.userInfo type:XCCObjj2ObjcSkeletonOperationErrorType])
        [self.cappuccinoProjectController.cappuccinoProject addOperationError:operationError];
    
    [self reload];
    
    [CappuccinoUtils notifyUserWithTitle:self.cappuccinoProjectController.cappuccinoProject.nickname
                                 message:[NSString stringWithFormat:@"Error: %@", [note.userInfo[@"sourcePath"] lastPathComponent]]];
}

- (void)_didReceiveObjjDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    for (XCCOperationError *operationError in [ObjjUtils operationErrorsFromDictionary:note.userInfo])
        [self.cappuccinoProjectController.cappuccinoProject addOperationError:operationError];
    
    [self reload];
    
    [CappuccinoUtils notifyUserWithTitle:self.cappuccinoProjectController.cappuccinoProject.nickname
                                 message:[NSString stringWithFormat:@"Warning: %@", [note.userInfo[@"sourcePath"] lastPathComponent]]];
    
}

- (void)_didReceiveNib2CibDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self.cappuccinoProjectController.cappuccinoProject addOperationError:[XCCOperationError nib2cibOperationErrorFromDictionary:note.userInfo]];
    [self reload];
    
    [CappuccinoUtils notifyUserWithTitle:self.cappuccinoProjectController.cappuccinoProject.nickname
                                 message:[NSString stringWithFormat:@"Error nib2cib : %@", [note.userInfo[@"sourcePath"] lastPathComponent]]];
    
}

- (void)_didReceiveCappLintDidGenerateErrorNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    for (XCCOperationError *operationError in [CappLintUtils operationErrorsFromDictionary:note.userInfo])
        [self.cappuccinoProjectController.cappuccinoProject addOperationError:operationError];
    
    [CappuccinoUtils notifyUserWithTitle:self.cappuccinoProjectController.cappuccinoProject.nickname
                                 message:[NSString stringWithFormat:@"Warning: %@", [note.userInfo[@"sourcePath"] lastPathComponent]]];
}

- (void)_didReceiveConversionDidEndNotification:(NSNotification *)note
{
    if (![self _doesNotificationBelongToCurrentProject:note])
        return;
    
    [self reload];
    [self.cappuccinoProjectController.mainXcodeCappController reloadTotalNumberOfErrors];
}

#pragma mark - Utilities

- (void)_showMaskingView:(BOOL)shouldShow
{
    if (shouldShow)
    {
        if (self->maskingView.superview)
            return;

        [self->errorOutlineView setHidden:YES];

        self->maskingView.frame = [self.view bounds];
        [self.view addSubview:self->maskingView positioned:NSWindowAbove relativeTo:nil];
    }
    else
    {
        if (!self->maskingView.superview)
            return;

        [self->errorOutlineView setHidden:NO];

        [self->maskingView removeFromSuperview];
    }
}

- (void)reload
{
    [self->errorOutlineView reloadData];
    [self->errorOutlineView expandItem:nil expandChildren:YES];

    [self _showMaskingView:!self.cappuccinoProjectController.cappuccinoProject.errors.count];
}


#pragma mark - Actions

- (IBAction)cleanProjectErrors:(id)aSender
{
    [self.cappuccinoProjectController.cappuccinoProject removeAllOperationErrors];
    [self reload];
}

- (IBAction)openErroredFileInEditor:(NSView *)sender
{
    id dataView;

    if (sender != self->errorOutlineView)
    {
        dataView = [self->errorOutlineView viewAtColumn:0 row:[self->errorOutlineView rowForView:sender] makeIfNecessary:NO];
    }
    else
    {
        dataView = [self->errorOutlineView viewAtColumn:0 row:[self->errorOutlineView selectedRow] makeIfNecessary:NO];
    }

    if (![dataView isKindOfClass:[XCCOperationErrorDataView class]])
        return;

    NSString *path = ((XCCOperationErrorDataView*)dataView).errorOperation.fileName;
    NSInteger line = ((XCCOperationErrorDataView*)dataView).errorOperation.lineNumber.intValue;


    [self.cappuccinoProjectController launchEditorForPath:path line:line];
    
}

#pragma mark - outlineView data source and delegate

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (!item)
        return self.cappuccinoProjectController.cappuccinoProject.errors.allKeys.count;

    return ((NSArray *)self.cappuccinoProjectController.cappuccinoProject.errors[item]).count;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return ![item isKindOfClass:[XCCOperationError class]];
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
    if (!item)
        return self.cappuccinoProjectController.cappuccinoProject.errors.allKeys[index];

    return self.cappuccinoProjectController.cappuccinoProject.errors[item][index];
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    return item;
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([item isKindOfClass:[XCCOperationError class]])
    {
        XCCOperationErrorDataView *dataView = [outlineView makeViewWithIdentifier:@"OperationErrorCell" owner:nil];

        dataView.errorOperation = item;
        [dataView.buttonOpenInEditor setTarget:self];
        [dataView.buttonOpenInEditor setAction:@selector(openErroredFileInEditor:)];

        return dataView;
    }
    else
    {
        XCCOperationErrorHeaderDataView *dataView = [outlineView makeViewWithIdentifier:@"OperationErrorHeaderCell" owner:nil];

        dataView.fileName = [[item stringByReplacingOccurrencesOfString:self.cappuccinoProjectController.cappuccinoProject.projectPath withString:@""] substringFromIndex:1];

        return dataView;
    }
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(XCCOperationError *)item
{
    if ([item isKindOfClass:[XCCOperationError class]])
    {
        CGRect frame = [item.message boundingRectWithSize:CGSizeMake([outlineView frame].size.width, CGFLOAT_MAX)
                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                               attributes:@{ NSFontAttributeName:[NSFont fontWithName:@"Menlo" size:11] }];

        return frame.size.height + 38.0;
    }

    else
        return 20.0;
}

@end
