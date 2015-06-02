//
//  CappuccinoProjectCellView.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/11/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCCappuccinoProjectControllerDataView.h"
#import "XCCCappuccinoProject.h"
#import "CappuccinoUtils.h"

static NSColor * XCCCappuccinoProjectDataViewColorLoading;
static NSColor * XCCCappuccinoProjectDataViewColorStopped;
static NSColor * XCCCappuccinoProjectDataViewColorListening;
static NSColor * XCCCappuccinoProjectDataViewColorProcessing;
static NSColor * XCCCappuccinoProjectDataViewColorError;


@implementation XCCCappuccinoProjectControllerDataView

+ (void)initialize
{
    XCCCappuccinoProjectDataViewColorLoading     = [NSColor colorWithCalibratedRed:107.0/255.0 green:148.0/255.0 blue:236.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorStopped     = [NSColor colorWithCalibratedRed:138.0/255.0 green:138.0/255.0 blue:138.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorListening   = [NSColor colorWithCalibratedRed:179.0/255.0 green:214.0/255.0 blue:69.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorProcessing  = [NSColor colorWithCalibratedRed:107.0/255.0 green:148.0/255.0 blue:236.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorError       = [NSColor colorWithCalibratedRed:247.0/255.0 green:97.0/255.0 blue:89.0/255.0 alpha:1.0];
}

- (void)setController:(XCCCappuccinoProjectController *)controller
{
    [self willChangeValueForKey:@"controller"];
    _controller = controller;
    [self didChangeValueForKey:@"controller"];
    
    [self.buttonSwitchStatus setTarget:controller];
    [self.buttonSwitchStatus setAction:@selector(switchProjectListeningStatus:)];
    
    [self.buttonOpenXcodeProject setTarget:controller];
    [self.buttonOpenXcodeProject setAction:@selector(openXcodeProject:)];
    
    [self.buttonResetProject setTarget:controller];
    [self.buttonResetProject setAction:@selector(resetProject:)];
    
    [self.buttonOpenInEditor setTarget:controller];
    [self.buttonOpenInEditor setAction:@selector(openProjectInEditor:)];
    
    [self.buttonOpenInFinder setTarget:controller];
    [self.buttonOpenInFinder setAction:@selector(openProjectInFinder:)];
    
    [self.buttonOpenInTerminal setTarget:controller];
    [self.buttonOpenInTerminal setAction:@selector(openProjectInTerminal:)];

    
    self.boxStatus.borderColor  = [NSColor clearColor];
    self.boxStatus.fillColor    = [NSColor colorWithCalibratedRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0];
    [self.waitingProgressIndicator startAnimation:self];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow)
    {
        [self.controller.cappuccinoProject addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [self.controller.cappuccinoProject addObserver:self forKeyPath:@"errors" options:NSKeyValueObservingOptionNew context:nil];
        
        NSDictionary *options = @{NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName};
        [self.operationsProgressIndicator bind:NSValueBinding toObject:self.controller withKeyPath:@"operationsProgress" options:nil];
        [self.operationsProgressIndicator bind:NSHiddenBinding toObject:self.controller withKeyPath:@"operationsTotal" options:options];
        [self.waitingProgressIndicator bind:NSHiddenBinding toObject:self.controller.cappuccinoProject withKeyPath:@"isBusy" options:options];
        [self.waitingProgressIndicator bind:@"hidden2" toObject:self.controller withKeyPath:@"operationsTotal" options:nil];
        [self.textField bind:NSValueBinding toObject:self.controller.cappuccinoProject withKeyPath:@"nickname" options:nil];
        [self.pathTextField bind:NSValueBinding toObject:self.controller.cappuccinoProject withKeyPath:@"projectPath" options:nil];
    }
    else
    {
        [self.controller.cappuccinoProject removeObserver:self forKeyPath:@"status"];
        [self.controller.cappuccinoProject removeObserver:self forKeyPath:@"errors"];
        [self.operationsProgressIndicator unbind:NSValueBinding];
        [self.operationsProgressIndicator unbind:NSHiddenBinding];
        [self.waitingProgressIndicator unbind:NSHiddenBinding];
        [self.waitingProgressIndicator unbind:@"hidden2"];
        [self.textField unbind:NSValueBinding];
        [self.pathTextField unbind:NSValueBinding];
    }
    
    [self _updateDataView];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [self _updateDataView];
}

- (void)_updateDataView
{
    switch (self.controller.cappuccinoProject.status)
    {
        case XCCCappuccinoProjectStatusInitialized:
        case XCCCappuccinoProjectStatusStopped:
            self.boxStatus.fillColor            = XCCCappuccinoProjectDataViewColorStopped;
            self.buttonSwitchStatus.enabled     = YES;
            self.buttonOpenXcodeProject.hidden  = YES;
            self.buttonResetProject.hidden      = YES;
            self.buttonSwitchStatus.image       = [NSImage imageNamed:@"run"];
            break;
            
        case XCCCappuccinoProjectStatusLoading:
            self.boxStatus.fillColor            = XCCCappuccinoProjectDataViewColorLoading;
            self.buttonSwitchStatus.enabled     = NO;
            self.buttonOpenXcodeProject.hidden  = YES;
            self.buttonResetProject.hidden      = YES;
            break;
            
        case XCCCappuccinoProjectStatusListening:
            self.boxStatus.fillColor            = [self.controller.cappuccinoProject.errors count] ? XCCCappuccinoProjectDataViewColorError : XCCCappuccinoProjectDataViewColorListening;
            self.buttonSwitchStatus.enabled     = YES;
            self.buttonOpenXcodeProject.hidden  = NO;
            self.buttonResetProject.hidden      = NO;
            self.buttonSwitchStatus.image       = [NSImage imageNamed:@"stop"];
            break;
            
        case XCCCappuccinoProjectStatusProcessing:
            self.boxStatus.fillColor            = XCCCappuccinoProjectDataViewColorProcessing;
            self.buttonSwitchStatus.enabled     = YES;
            self.buttonOpenXcodeProject.hidden  = NO;
            self.buttonResetProject.hidden      = NO;
            self.buttonSwitchStatus.image       = [NSImage imageNamed:@"stop"];
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
