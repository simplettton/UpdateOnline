//
//  AppDelegate.m
//  UpdateOnline
//
//  Created by Macmini on 2017/12/14.
//  Copyright © 2017年 Shenzhen Lifotronic Technology Co.,Ltd. All rights reserved.
//

#import "AppDelegate.h"
NSString * const KOpenFileNotification = @"KOpenFileNotification";
NSString * const KFileName = @"KFileName";
NSString * const KFilePath = @"KFilePath";
NSString * const DEFAULTHostSetting = @"10.10.100.254";
NSString * const DEFAULTPortSetting = @"8080";

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [self configAirWaveNetworkSetting];
    return YES;
}
-(void)configAirWaveNetworkSetting
{
    self.host = DEFAULTHostSetting;
    self.port = DEFAULTPortSetting;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
        if (url)
        {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSString *fileNameStr = [url lastPathComponent];
            NSData *data = [NSData dataWithContentsOfURL:url];
            //documents路径
            NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];

            //documents有文件则删除
            NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager]enumeratorAtPath:documents];
            if(enumerator !=nil)
            {
                for (NSString *fileName in enumerator)
                {
                    BOOL isDirectory = NO;
                    [[NSFileManager defaultManager] fileExistsAtPath:[documents stringByAppendingPathComponent:fileName] isDirectory:&isDirectory];
                    if (!isDirectory)
                    {
                          [fileManager removeItemAtPath:[documents stringByAppendingPathComponent:fileName] error:nil];
                    }
                }
            }
            NSString *documentPath = [documents stringByAppendingPathComponent:fileNameStr];
//            if (![fileManager fileExistsAtPath:documentPath])
//            {
//                [fileManager createFileAtPath:documentPath contents:nil attributes:nil];
//            }
            //保存新文件
            BOOL success = [data writeToFile:documentPath atomically:YES];
            if (success)
            {
                //写入成功发送通知
                NSDictionary *dict= @{KFilePath:documentPath,KFileName:fileNameStr};
                [[NSNotificationCenter defaultCenter]postNotificationName:KOpenFileNotification object:nil userInfo:dict];
            }
        }
    return YES;
}


@end
