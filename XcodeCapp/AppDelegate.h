//
//  AppDelegate.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/5/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreServices/CoreServices.h>

@class CappuccinoController;
@class XCCMainController;

@interface AppDelegate : NSObject <NSApplicationDelegate>
{
    
}

@property (strong) IBOutlet NSUserDefaultsController    *preferencesController;
@property (strong) IBOutlet NSPanel                     *aboutWindow;
@property (strong) IBOutlet NSWindow                    *preferencesWindow;
@property (strong) IBOutlet CappuccinoController        *cappuccinoController;
@property (strong) IBOutlet XCCMainController           *mainWindowController;

@property (strong) NSOperationQueue                     *mainOperationQueue;


- (IBAction)openAbout:(id)aSender;
- (IBAction)openPreferences:(id)aSender;

@end

