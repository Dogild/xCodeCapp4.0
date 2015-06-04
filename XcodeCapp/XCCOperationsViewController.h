//
//  XCCOperationsViewController.h
//  XcodeCapp
//
//  Created by Antoine Mercadal on 6/4/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class XCCCappuccinoProjectController;


@interface XCCOperationsViewController : NSViewController <NSTableViewDataSource, NSTableViewDelegate>
{
    IBOutlet NSTableView                    *operationTableView;
    IBOutlet NSBox                          *maskingView;
}

@property XCCCappuccinoProjectController *cappuccinoProjectController;

- (void)reload;

@end
