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

@synthesize controller = _controller;

+ (void)initialize
{
    XCCCappuccinoProjectDataViewColorLoading     = [NSColor colorWithCalibratedRed:107.0/255.0 green:148.0/255.0 blue:236.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorStopped     = [NSColor colorWithCalibratedRed:138.0/255.0 green:138.0/255.0 blue:138.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorListening   = [NSColor colorWithCalibratedRed:179.0/255.0 green:214.0/255.0 blue:69.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorProcessing  = [NSColor colorWithCalibratedRed:107.0/255.0 green:148.0/255.0 blue:236.0/255.0 alpha:1.0];
    XCCCappuccinoProjectDataViewColorError       = [NSColor colorWithCalibratedRed:247.0/255.0 green:97.0/255.0 blue:89.0/255.0 alpha:1.0];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if (newWindow)
    {
        [self->buttonSwitchStatus setTarget:self.controller];
        [self->buttonSwitchStatus setAction:@selector(switchProjectListeningStatus:)];
        [self->buttonOpenXcodeProject setTarget:self.controller];
        [self->buttonOpenXcodeProject setAction:@selector(openProjectInXcode:)];
        [self->buttonResetProject setTarget:self.controller];
        [self->buttonResetProject setAction:@selector(resetProject:)];
        [self->buttonOpenInEditor setTarget:self.controller];
        [self->buttonOpenInEditor setAction:@selector(openProjectInEditor:)];
        [self->buttonOpenInFinder setTarget:self.controller];
        [self->buttonOpenInFinder setAction:@selector(openProjectInFinder:)];
        [self->buttonOpenInTerminal setTarget:self.controller];
        [self->buttonOpenInTerminal setAction:@selector(openProjectInTerminal:)];
        
        self->boxStatus.borderColor  = [NSColor clearColor];
        self->boxStatus.fillColor    = [NSColor colorWithCalibratedRed:217.0/255.0 green:217.0/255.0 blue:217.0/255.0 alpha:1.0];
        
        [self->waitingProgressIndicator startAnimation:self];
        
        [self.controller.cappuccinoProject addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
        [self.controller.cappuccinoProject addObserver:self forKeyPath:@"errors" options:NSKeyValueObservingOptionNew context:nil];
        
        NSDictionary *options = @{NSValueTransformerNameBindingOption: NSNegateBooleanTransformerName};
        [self->operationsProgressIndicator bind:NSValueBinding toObject:self.controller withKeyPath:@"operationsProgress" options:nil];
        [self->operationsProgressIndicator bind:NSHiddenBinding toObject:self.controller withKeyPath:@"operationsTotal" options:options];
        [self->waitingProgressIndicator bind:NSHiddenBinding toObject:self.controller.cappuccinoProject withKeyPath:@"isBusy" options:options];
        [self->waitingProgressIndicator bind:@"hidden2" toObject:self.controller withKeyPath:@"operationsTotal" options:nil];
        [self->fieldNickname bind:NSValueBinding toObject:self.controller.cappuccinoProject withKeyPath:@"nickname" options:nil];
        [self->fieldPath bind:NSValueBinding toObject:self.controller.cappuccinoProject withKeyPath:@"projectPath" options:nil];
    }
    else
    {
        [self->waitingProgressIndicator stopAnimation:self];
        
        [self.controller.cappuccinoProject removeObserver:self forKeyPath:@"status"];
        [self.controller.cappuccinoProject removeObserver:self forKeyPath:@"errors"];
        
        [self->operationsProgressIndicator unbind:NSValueBinding];
        [self->operationsProgressIndicator unbind:NSHiddenBinding];
        [self->waitingProgressIndicator unbind:NSHiddenBinding];
        [self->waitingProgressIndicator unbind:@"hidden2"];
        [self->fieldNickname unbind:NSValueBinding];
        [self->fieldPath unbind:NSValueBinding];
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
            self->boxStatus.fillColor            = XCCCappuccinoProjectDataViewColorStopped;
            self->buttonSwitchStatus.image       = self.backgroundStyle == NSBackgroundStyleDark ? [NSImage imageNamed:@"run-white"] : [NSImage imageNamed:@"run"];
            break;
            
        case XCCCappuccinoProjectStatusLoading:
            self->boxStatus.fillColor            = XCCCappuccinoProjectDataViewColorLoading;
            self->buttonSwitchStatus.image       = self.backgroundStyle == NSBackgroundStyleDark ? [NSImage imageNamed:@"stop-white"] : [NSImage imageNamed:@"stop"];
            break;
            
        case XCCCappuccinoProjectStatusListening:
            self->boxStatus.fillColor            = [self.controller.cappuccinoProject.errors count] ? XCCCappuccinoProjectDataViewColorError : XCCCappuccinoProjectDataViewColorListening;
            self->buttonSwitchStatus.image       = self.backgroundStyle == NSBackgroundStyleDark ? [NSImage imageNamed:@"stop-white"] : [NSImage imageNamed:@"stop"];
            break;
            
        case XCCCappuccinoProjectStatusProcessing:
            self->boxStatus.fillColor            = XCCCappuccinoProjectDataViewColorProcessing;
            self->buttonSwitchStatus.image       = self.backgroundStyle == NSBackgroundStyleDark ? [NSImage imageNamed:@"stop-white"] : [NSImage imageNamed:@"stop"];
            break;
    }
}

- (void)setBackgroundStyle:(NSBackgroundStyle)backgroundStyle
{
    BOOL isStopped = (self.controller.cappuccinoProject.status == XCCCappuccinoProjectStatusStopped || self.controller.cappuccinoProject.status == XCCCappuccinoProjectStatusInitialized);
    
    if (backgroundStyle == NSBackgroundStyleDark)
    {
        self->lineBottom.hidden = YES;
        
        self->fieldNickname.textColor        = [NSColor whiteColor];
        self->fieldPath.textColor            = [NSColor whiteColor];
        self->buttonSwitchStatus.image       = isStopped ? [NSImage imageNamed:@"run-white"] : [NSImage imageNamed:@"stop-white"];
        self->buttonOpenInFinder.image       = [NSImage imageNamed:@"open-in-finder-white"];
        self->buttonOpenInEditor.image       = [NSImage imageNamed:@"open-in-editor-white"];
        self->buttonOpenInTerminal.image     = [NSImage imageNamed:@"open-in-terminal-white"];
        self->buttonOpenXcodeProject.image   = [NSImage imageNamed:@"open-in-xcode-white"];
        self->buttonResetProject.image       = [NSImage imageNamed:@"resync-white"];
    }
    else
    {
        self->lineBottom.hidden = NO;

        self->fieldNickname.textColor        = [NSColor controlTextColor];
        self->fieldPath.textColor            = [NSColor secondaryLabelColor];
        self->buttonSwitchStatus.image       = isStopped ? [NSImage imageNamed:@"run"] : [NSImage imageNamed:@"stop"];
        self->buttonOpenInFinder.image       = [NSImage imageNamed:@"open-in-finder"];
        self->buttonOpenInEditor.image       = [NSImage imageNamed:@"open-in-editor"];
        self->buttonOpenInTerminal.image     = [NSImage imageNamed:@"open-in-terminal"];
        self->buttonOpenXcodeProject.image   = [NSImage imageNamed:@"open-in-xcode"];
        self->buttonResetProject.image       = [NSImage imageNamed:@"resync"];
    }

    [super setBackgroundStyle:backgroundStyle];
}

@end
