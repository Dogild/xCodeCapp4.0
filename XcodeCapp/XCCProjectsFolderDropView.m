//
//  XCCProjectsFolderDropView.m
//  XcodeCapp
//
//  Created by Antoine Mercadal on 6/4/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "XCCProjectsFolderDropView.h"
#import "XCCMainController.h"

@implementation XCCProjectsFolderDropView

- (void)awakeFromNib
{
    [self registerForDraggedTypes:@[NSFilenamesPboardType]];
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)info
{
    NSPasteboard *pboard = [info draggingPasteboard];

    if ([pboard.types containsObject:(NSString *)NSFilenamesPboardType])
    {
        NSArray *draggedFiles = [pboard propertyListForType:(NSString *)NSFilenamesPboardType];

        for (NSString *file in draggedFiles)
        {
            BOOL isDir;
            [[NSFileManager defaultManager] fileExistsAtPath:file isDirectory:&isDir];

            if (!isDir)
                return NSDragOperationNone;
        }

        self.fillColor = [NSColor colorWithCalibratedRed:236.0/255.0 green:236.0/255.0 blue:236.0/255.0 alpha:1.0];
        return NSDragOperationCopy;
    }

    return NSDragOperationNone;
}

- (void)draggingExited:(id<NSDraggingInfo>)info
{
    self.fillColor = [NSColor whiteColor];
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)info
{
    return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)info
{
    NSPasteboard *pboard = [info draggingPasteboard];

    if ([pboard.types containsObject:(NSString *)NSFilenamesPboardType])
    {
        NSArray *draggedFolders = [pboard propertyListForType:(NSString *)NSFilenamesPboardType];

        for (NSString *folder in draggedFolders)
            [self.mainXcodeCappController manageCappuccinoProjectControllerForPath:folder];

        return YES;
    }

    return NO;
}

- (void)concludeDragOperation:(id<NSDraggingInfo>)info
{
    self.fillColor = [NSColor whiteColor];
}

@end
