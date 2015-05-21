//
//  CappuccinoProjectViewCell.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/11/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "CappuccinoProjectViewCell.h"
#import "CappuccinoProject.h"
#import "CappuccinoUtils.h"

@implementation CappuccinoProjectViewCell

- (void)setCappuccinoProject:(CappuccinoProject *)cappuccinoProject
{
    [self willChangeValueForKey:@"cappuccinoProject"];
    _cappuccinoProject = cappuccinoProject;
    [self didChangeValueForKey:@"cappuccinoProject"];
    
    [self.textField setStringValue:[cappuccinoProject projectName]];
    [self.pathTextField setStringValue:[cappuccinoProject projectPath]];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow)
    {
        [self.cappuccinoProject addObserver:self forKeyPath:@"isListeningProject" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"isLoadingProject" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"isProjectLoaded" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"isProcessingProject" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"warnings" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"errors" options:NSKeyValueObservingOptionNew context:nil];
    }
    else
    {
        [self.cappuccinoProject removeObserver:self forKeyPath:@"isListeningProject"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"isLoadingProject"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"isProjectLoaded"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"isProcessingProject"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"warnings"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"errors"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self.cappuccinoProject)
    {
        if (self.cappuccinoProject.isLoadingProject || self.cappuccinoProject.isProcessingProject)
            self.imageView.image = [CappuccinoUtils iconWorking];
        else if ([self.cappuccinoProject.errors count])
            self.imageView.image = [CappuccinoUtils iconError];
        else if ([self.cappuccinoProject.warnings count])
            self.imageView.image = [CappuccinoUtils iconWarning];
        else if (self.cappuccinoProject.isListeningProject)
            self.imageView.image = [CappuccinoUtils iconActive];
        else
            self.imageView.image = [CappuccinoUtils iconInactive];
        
        if (self.cappuccinoProject.isLoadingProject)
        {
            [self.loadButton setEnabled:NO];
            self.loadButton.title = @"Loading";
        }
        else if (self.cappuccinoProject.isProjectLoaded)
        {
            if (self.cappuccinoProject.isListeningProject)
                self.loadButton.title = @"Stop listening";
            else
                self.loadButton.title = @"Start listening";
                    
            [self.loadButton setEnabled:YES];
        }
        else
        {
            self.loadButton.title = @"Load";
            [self.loadButton setEnabled:YES];
        }
        
        [self.loadButton sizeToFit];
    }
}

@end
