//
//  pack.h
//  AirWave
//
//  Created by Macmini on 2017/8/22.
//  Copyright © 2017年 Shenzhen Lifotronic Technology Co.,Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>
@interface Pack : NSObject
+(NSData *)packetWithCmdid:(Byte)cmdid addressEnabled:(BOOL)addrEnabled addr:(NSData *)addr dataEnabled:(BOOL)dataEnabled data:(NSData *)data;
@end
