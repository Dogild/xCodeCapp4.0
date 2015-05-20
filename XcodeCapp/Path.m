//
//  Path.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/20/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "Path.h"

@implementation Path

- (instancetype)init
{
    self = [super init];
    
    if (self)
    {
        self.name = @"~/bin";
    }
    
    return self;
}


@end
