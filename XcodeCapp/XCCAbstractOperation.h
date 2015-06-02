//
//  XCCAbstractOperation.h
//  XcodeCapp
//
//  Created by Antoine Mercadal on 6/2/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "XCCCappuccinoProject.h"
#import "CappuccinoUtils.h"

@class XCCCappuccinoProject;

@interface XCCAbstractOperation : NSOperation

@property XCCCappuccinoProject *cappuccinoProject;

@end
