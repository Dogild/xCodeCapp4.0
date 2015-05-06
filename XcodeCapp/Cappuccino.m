//
//  Cappuccino.m
//  XcodeCapp
//
//  Created by Alexandre Wilhelm on 5/6/15.
//  Copyright (c) 2015 cappuccino-project. All rights reserved.
//

#import "Cappuccino.h"
#import "TaskManager.h"
#import "UserDefaults.h"

@implementation Cappuccino

- (void)awakeFromNib
{
    _taskManager = [TaskManager new];
}

- (IBAction)update:(id)aSender
{
    if (_isUpdating)
        return;
    
    DDLogVerbose(@"Cappuccino Updating : start");
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    _isUpdating = YES;
    
    NSString *temporaryFolder = NSTemporaryDirectory();
    
    if (![self _downloadCappuccinoInFolder:temporaryFolder] ||
        ![self _unzipCappuccinoInFolder:temporaryFolder] ||
        ![self _clobberCappuccinoInFolder:temporaryFolder] ||
        ![self _installCappuccinoInFolder:temporaryFolder])
    {
        _isUpdating = NO;
        DDLogVerbose(@"Cappuccino Updating : something went wrong when downloading Cappuccino");
        return;
    }
    
    _isUpdating = NO;
    DDLogVerbose(@"Cappuccino Updating : Cappuccino has been well updated");
}

- (BOOL)_downloadCappuccinoInFolder:(NSString*)aFolder
{
    DDLogVerbose(@"Cappuccino Updating : downloading cappuccino");
    
    //Be sure to remove an old install
    NSMutableArray *rmArguments = [NSMutableArray arrayWithObjects:@"-r", @"cappuccino", nil];
    [_taskManager runTaskWithCommand:@"rm"
                   arguments:rmArguments
                  returnType:kTaskReturnTypeAny
        currentDirectoryPath:aFolder];
    
    // Here we will download cappuccino
    NSString *cappuccinoURL;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:kDefaultXCCUpdateCappuccinoWithLastVersionOfMasterBranch])
        cappuccinoURL = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"XCCLastCappuccinoMasterBranchURL"];
    else
        cappuccinoURL = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"XCCLastCappuccinoReleaseURL"];
    
    NSString *destination = [NSString stringWithFormat:@"%@cappuccino.zip", aFolder];
    NSMutableArray *arguments = [NSMutableArray arrayWithObjects:@"-Lk", cappuccinoURL, @"-o", destination, nil];
    NSDictionary *taskResult = [_taskManager runTaskWithCommand:@"curl"
                                              arguments:arguments
                                             returnType:kTaskReturnTypeStdOut];
    
    NSInteger status = [taskResult[@"status"] intValue];
    
    if (status > 1)
    {
        DDLogVerbose(@"Cappuccino Updating : unable to download Cappuccino");
        return NO;
    }
    
    return YES;
}

- (BOOL)_unzipCappuccinoInFolder:(NSString*)aFolder
{
    // Then we will unzip the file
    NSMutableArray *unzipArguments = [NSMutableArray arrayWithObjects:@"-u", @"-o", @"-q", @"-d", @"cappuccino", @"cappuccino.zip", nil];
    NSDictionary *unzipTaskResult = [_taskManager runTaskWithCommand:@"unzip"
                                                           arguments:unzipArguments
                                                          returnType:kTaskReturnTypeAny
                                                currentDirectoryPath:aFolder];
    
    NSInteger unzipStatus = [unzipTaskResult[@"status"] intValue];
    
    if (unzipStatus >= 1)
    {
        DDLogVerbose(@"Cappuccino Updating : unable to unzip Cappuccino");
        return NO;
    }
    
    return YES;
}

- (BOOL)_clobberCappuccinoInFolder:(NSString*)aFolder
{
    NSString* path = [self _cappuccinoPathForFolder:aFolder];
    
    //Jake clobber
    NSMutableArray *jakeClobberArguments = [NSMutableArray arrayWithObjects:@"clobber", nil];
    NSDictionary *jakeClobberTaskResult = [_taskManager runJakeTaskWithArguments:jakeClobberArguments currentDirectoryPath:path];
    
    NSInteger jakeInstallStatus = [jakeClobberTaskResult[@"status"] intValue];
    
    if (jakeInstallStatus == 1)
    {
        DDLogVerbose(@"Jake clobber failed: %@", jakeClobberTaskResult[@"response"]);
        return NO;
    }
    
    return YES;
}

- (BOOL)_installCappuccinoInFolder:(NSString*)aFolder
{
    NSString* path = [self _cappuccinoPathForFolder:aFolder];
    
    //Jake install
    NSMutableArray *jakeInstallArguments = [NSMutableArray arrayWithObjects:@"install", nil];
    NSDictionary *jakeInstallTaskResult = [_taskManager runJakeTaskWithArguments:jakeInstallArguments currentDirectoryPath:path];
    
    NSInteger jakeInstallStatus = [jakeInstallTaskResult[@"status"] intValue];
    
    if (jakeInstallStatus == 1)
    {
        DDLogVerbose(@"Jake install failed: %@", jakeInstallTaskResult[@"response"]);
        return NO;
    }
    
    return YES;
}

/*!
 This return the current path where the tmp cappuccino was downloaded
 */
- (NSString*)_cappuccinoPathForFolder:(NSString*)aFolder
{
    NSFileManager *fileManger = [NSFileManager defaultManager];
    NSString *contentOfCappuccinoFolder = [[fileManger contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@cappuccino", aFolder] error:nil] firstObject];
    
    return [NSString stringWithFormat:@"%@cappuccino/%@", aFolder, contentOfCappuccinoFolder];
}

@end
