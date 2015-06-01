//
//  CappuccinoProjectCellView.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/11/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "CappuccinoProjectCellView.h"
#import "CappuccinoProject.h"
#import "CappuccinoUtils.h"

@implementation CappuccinoProjectCellView

- (void)setCappuccinoProject:(CappuccinoProject *)cappuccinoProject
{
    [self willChangeValueForKey:@"cappuccinoProject"];
    _cappuccinoProject = cappuccinoProject;
    [self didChangeValueForKey:@"cappuccinoProject"];
    
    [self.textField setStringValue:[cappuccinoProject projectName]];
    [self.pathTextField setStringValue:[cappuccinoProject projectPath]];
    
    self.boxStatus.borderColor = [NSColor clearColor];
    self.boxStatus.fillColor = [NSColor colorWithCalibratedRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow)
    {
        [self.cappuccinoProject addObserver:self forKeyPath:@"isListening" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"isLoading" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"isLoaded" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"isProcessing" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"warnings" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"errors" options:NSKeyValueObservingOptionNew context:nil];
    }
    else
    {
        [self.cappuccinoProject removeObserver:self forKeyPath:@"isListening"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"isLoading"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"isLoaded"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"isProcessing"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"warnings"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"errors"];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object != self.cappuccinoProject)
        return;

    if (self.cappuccinoProject.isLoading || self.cappuccinoProject.isProcessing)
        self.boxStatus.fillColor = [NSColor colorWithCalibratedRed:107.0/255.0 green:148.0/255.0 blue:236.0/255.0 alpha:1.0];
    else if ([self.cappuccinoProject.errors count])
        self.boxStatus.fillColor = [NSColor colorWithCalibratedRed:247.0/255.0 green:97.0/255.0 blue:89.0/255.0 alpha:1.0];
    else if (self.cappuccinoProject.isListening)
        self.boxStatus.fillColor = [NSColor colorWithCalibratedRed:179.0/255.0 green:214.0/255.0 blue:69.0/255.0 alpha:1.0];
    else
        self.boxStatus.fillColor = [NSColor colorWithCalibratedRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0];
    
    if (self.cappuccinoProject.isLoading || self.cappuccinoProject.isListening)
        self.loadButton.image = [NSImage imageNamed:@"stop"];
    else
        self.loadButton.image = [NSImage imageNamed:@"run"];
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    NSColor *textColor = (backgroundStyle == NSBackgroundStyleDark) ? [NSColor windowBackgroundColor] : [NSColor controlShadowColor];
    self.pathTextField.textColor = textColor;
    [super setBackgroundStyle:backgroundStyle];
}

@end
