//
//  Cappuccino.h
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>

@class TaskManager;

@interface Cappuccino : NSObject
{
    BOOL            _isUpdating;
    TaskManager     *_taskManager;
}

- (IBAction)update:(id)aSender;

@end
