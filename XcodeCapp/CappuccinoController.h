//
//  CappuccinoController.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TaskManager;
@class MainWindowController;

@interface CappuccinoController : NSObject
{
    BOOL            _isUpdating;
    TaskManager     *_taskManager;
}

@property IBOutlet MainWindowController *mainWindowController;

- (IBAction)update:(id)aSender;
- (IBAction)createProject:(id)aSender;

@end
