//
//  AppDelegate.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/5/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, NSSplitViewDelegate>

@property (strong) IBOutlet NSSplitView    *splitView;

@property (strong) IBOutlet NSPanel    *aboutWindow;

- (IBAction)openAbout:(id)aSender;

@end

