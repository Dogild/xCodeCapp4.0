//
//  OperationErrorHeaderCellView.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/22/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "OperationErrorHeaderCellView.h"


@implementation OperationErrorHeaderCellView

- (void)setObjectValue:(id)aPath
{
    AppDelegate *appDelegate = (AppDelegate *)[NSApp delegate];
    CappuccinoProject *currentProject = appDelegate.mainWindowController.currentCappuccinoProject;

    NSString *path = [NSString stringWithFormat:@"%@/", currentProject.projectPath];
    NSString *text = [aPath stringByReplacingOccurrencesOfString:path withString:@""];
    
    if (text)
        self.textField.stringValue = text;
}
@end
