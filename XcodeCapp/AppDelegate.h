//
//  AppDelegate.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/5/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>

@class Cappuccino;

@interface AppDelegate : NSObject <NSApplicationDelegate, NSSplitViewDelegate, NSTableViewDataSource, NSTableViewDelegate>
{
    
}

@property (strong) IBOutlet NSUserDefaultsController    *preferencesController;

@property (strong) IBOutlet NSPanel    *aboutWindow;
@property (strong) IBOutlet NSWindow   *preferencesWindow;

@property (strong) IBOutlet NSSplitView    *splitView;
@property (strong) IBOutlet NSTableView    *projectTableView;

@property (strong) IBOutlet Cappuccino *cappuccino;

@property (strong) NSMutableArray *cappuccinoProjects;

- (IBAction)openAbout:(id)aSender;
- (IBAction)openPreferences:(id)aSender;

@end

