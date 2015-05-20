//
//  CappuccinoProjectViewCell.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/11/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "CappuccinoProjectViewCell.h"
#import "CappuccinoProjectController.h"
#import "CappuccinoUtils.h"

@implementation CappuccinoProjectViewCell

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow)
    {
        [self.controller addObserver:self forKeyPath:@"isListeningProject" options:NSKeyValueObservingOptionNew context:nil];
        [self.controller addObserver:self forKeyPath:@"isLoadingProject" options:NSKeyValueObservingOptionNew context:nil];
        [self.controller addObserver:self forKeyPath:@"isProjectLoaded" options:NSKeyValueObservingOptionNew context:nil];
        [self.controller addObserver:self forKeyPath:@"isProcessingProject" options:NSKeyValueObservingOptionNew context:nil];
        [self.controller addObserver:self forKeyPath:@"warnings" options:NSKeyValueObservingOptionNew context:nil];
        [self.controller addObserver:self forKeyPath:@"errors" options:NSKeyValueObservingOptionNew context:nil];
    }
    else
    {
        [self.controller removeObserver:self forKeyPath:@"isListeningProject"];
        [self.controller removeObserver:self forKeyPath:@"isLoadingProject"];
        [self.controller removeObserver:self forKeyPath:@"isProjectLoaded"];
        [self.controller removeObserver:self forKeyPath:@"isProcessingProject"];
        [self.controller removeObserver:self forKeyPath:@"warnings"];
        [self.controller removeObserver:self forKeyPath:@"errors"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self.controller)
    {
        if (self.controller.isLoadingProject || self.controller.isProcessingProject)
            self.imageView.image = [CappuccinoUtils iconWorking];
        else if ([self.controller.errors count])
            self.imageView.image = [CappuccinoUtils iconError];
        else if ([self.controller.warnings count])
            self.imageView.image = [CappuccinoUtils iconWarning];
        else if (self.controller.isListeningProject)
            self.imageView.image = [CappuccinoUtils iconActive];
        else
            self.imageView.image = [CappuccinoUtils iconInactive];
    }
}

@end
