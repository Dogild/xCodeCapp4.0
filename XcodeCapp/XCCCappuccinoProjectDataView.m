//
//  CappuccinoProjectCellView.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/11/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCCappuccinoProjectDataView.h"
#import "XCCCappuccinoProject.h"
#import "CappuccinoUtils.h"

static NSColor * XCCCappuccinoProjectDataViewColorLoading;
static NSColor * XCCCappuccinoProjectDataViewColorStopped;
static NSColor * XCCCappuccinoProjectDataViewColorListening;
static NSColor * XCCCappuccinoProjectDataViewColorProcessing;
static NSColor * XCCCappuccinoProjectDataViewColorError;


@implementation XCCCappuccinoProjectDataView

+ (void)initialize
{
    XCCCappuccinoProjectDataViewColorLoading     = [NSColor colorWithCalibratedRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorStopped     = [NSColor colorWithCalibratedRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorListening   = [NSColor colorWithCalibratedRed:179.0/255.0 green:214.0/255.0 blue:69.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorProcessing  = [NSColor colorWithCalibratedRed:107.0/255.0 green:148.0/255.0 blue:236.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorError       = [NSColor colorWithCalibratedRed:247.0/255.0 green:97.0/255.0 blue:89.0/255.0 alpha:1.0];
}

- (void)setCappuccinoProject:(XCCCappuccinoProject *)cappuccinoProject
{
    [self willChangeValueForKey:@"cappuccinoProject"];
    _cappuccinoProject = cappuccinoProject;
    [self didChangeValueForKey:@"cappuccinoProject"];
    
    [self.textField setStringValue:[cappuccinoProject name]];
    [self.pathTextField setStringValue:[cappuccinoProject projectPath]];
    
    self.boxStatus.borderColor = [NSColor clearColor];
    self.boxStatus.fillColor = [NSColor colorWithCalibratedRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow)
    {
        [self.cappuccinoProject addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [self.cappuccinoProject addObserver:self forKeyPath:@"errors" options:NSKeyValueObservingOptionNew context:nil];
    }
    else
    {
        [self.cappuccinoProject removeObserver:self forKeyPath:@"status"];
        [self.cappuccinoProject removeObserver:self forKeyPath:@"errors"];
    }
    
    [self _updateDataView];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self _updateDataView];
}

- (void)_updateDataView
{
    switch (self.cappuccinoProject.status)
    {
        case XCCCappuccinoProjectStatusLoading:
            self.boxStatus.fillColor    = XCCCappuccinoProjectDataViewColorLoading;
            self.loadButton.enabled     = NO;
            break;
            
        case XCCCappuccinoProjectStatusStopped:
            self.boxStatus.fillColor    = XCCCappuccinoProjectDataViewColorStopped;
            self.loadButton.enabled     = YES;
            self.loadButton.image       = [NSImage imageNamed:@"run"];
            break;
            
        case XCCCappuccinoProjectStatusListening:
            self.boxStatus.fillColor    = [self.cappuccinoProject.errors count] ? XCCCappuccinoProjectDataViewColorError : XCCCappuccinoProjectDataViewColorListening;
            self.loadButton.enabled     = YES;
            self.loadButton.image       = [NSImage imageNamed:@"stop"];
            break;
            
        case XCCCappuccinoProjectStatusProcessing:
            self.boxStatus.fillColor    = XCCCappuccinoProjectDataViewColorProcessing;
            self.loadButton.enabled     = YES;
            self.loadButton.image       = [NSImage imageNamed:@"stop"];
            break;
    }
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    NSColor *textColor = (backgroundStyle == NSBackgroundStyleDark) ? [NSColor windowBackgroundColor] : [NSColor controlShadowColor];
    self.pathTextField.textColor = textColor;
    [super setBackgroundStyle:backgroundStyle];
}

@end
