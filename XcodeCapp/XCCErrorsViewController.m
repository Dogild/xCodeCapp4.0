//
//  XCCErrorsViewController.m
//  XcodeCapp
//
//  Created by Antoine Mercadal on 6/4/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCErrorsViewController.h"
#import "XCCCappuccinoProjectController.h"
#import "XCCCappuccinoProject.h"
#import "XCCOperationErrorDataView.h"
#import "XCCOperationErrorHeaderDataView.h"


@implementation XCCErrorsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self->errorOutlineView setDoubleAction:@selector(openRelatedObjjFileInEditor:)];
    [self->errorOutlineView bind:NSTargetBinding toObject:self withKeyPath:@"cappuccinoProjectController" options:nil];
}

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

- (IBAction)cleanProjectErrors:(id)aSender
{
    [self.cappuccinoProjectController.cappuccinoProject removeAllOperationErrors];
    [self reload];
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
