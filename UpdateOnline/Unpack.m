//
//  Unpack.m
//  AirWave
//
//  Created by Macmini on 2017/11/9.
//  Copyright © 2017年 Shenzhen Lifotronic Technology Co.,Ltd. All rights reserved.
//

#import "Unpack.h"

@implementation Unpack
+(NSData *)unpackData:(NSData *)pdata
{
    UInt32 nheadPos = 0;
    Byte *dataBytes = (Byte *)[pdata bytes];
    NSInteger lengthOfData = [pdata length];
    //寻找头部
    BOOL hasHead = NO;
    for (UInt32 i = 0; i<lengthOfData; i++)
    {
        if (dataBytes[i]==0xaa)
        {
            if (i>0&&dataBytes[i-1]==0xcc)
                continue;
            hasHead = YES;
            //获取头部索引
            nheadPos = i;
            break;
        }
    }
    //找不到头部，返回错误
    if (!hasHead)
    {
        NSLog(@"error:cannot find head");
        return nil;
    }
    //寻找尾部（从包头开始）
    UInt32 nTailPos = 0;
    for (UInt32 i = nheadPos +1 ; i<lengthOfData; i++)
    {
        if (dataBytes[i]==0x55)
        {
            nTailPos = i;
            break;
        }
        if (dataBytes[i]==0xaa)
        {
            nTailPos = i - 1;
        }
    }
    //包不完整
    if (nTailPos<1)
    {
        NSLog(@"error:pack length error");
    }
    
    //对一个包进行反转义（除开包头包尾）
    UInt32 lengthOfTransData = nTailPos - nheadPos +1;
    uint8_t *ls = malloc(sizeof(*ls)*lengthOfTransData);
    UInt32 lengthOfLs = 0;
    for (UInt32 i = nheadPos+1; i<nTailPos; i++)
    {
        UInt8 curChar = dataBytes[i];
        if (curChar == 0xcc)
        {
            ls[lengthOfLs++] = dataBytes[++i]-1;
        }
        else
        {
            ls[lengthOfLs++] = dataBytes[i];
        }
    }
    
    //验证包长度
    
    UInt32 packLength = ls[0];
    if (lengthOfLs != packLength +2)
    {
        ls = NULL;
        nheadPos = nTailPos +1;
        NSLog(@"error:pack length error");
    }
    //获取尾部索引
//    *pIndexOfTail = nTailPos;
    
    //验证校验码
    NSData *crcData = [NSData dataWithBytes:ls length:packLength+1];
    UInt8 CRC8 = [self getCRC8WithData:crcData];
    if (CRC8 != ls[lengthOfLs -1]) {
        ls = NULL;
        NSLog(@"error:pack checkCrc error");
    }
    
    
    uint8_t *resultData = malloc(sizeof(*ls)*100);
    
    for (UInt32 i = 0; i<packLength; i++)
    {
        resultData[i] = ls[i+1];
    }
    
    NSData *dataWithCmdId = [NSData dataWithBytes:resultData length:packLength];
    return dataWithCmdId;
}
#pragma mark - Private Method
+(Byte)getCRC8WithData:(NSData *)dataArray
{
    if (NULL==dataArray || [dataArray length] < 1)
    {
        return 0xFF;
    }
    UInt16 crc,thisbyte,i,shift,lastbit;
    crc = 0xFFFF;
    Byte *byteArray = (Byte *)[dataArray bytes];
    
    for ( i=0 ; i<[dataArray length]; i++)
    {
        thisbyte = (UInt16)byteArray[i];
        crc = (UInt16)(crc^thisbyte);
        for (shift = 1; shift <= 8; shift++)
        {
            lastbit = (UInt16)(crc & 0X0001);
            crc = (UInt16)((crc >> 1) & 0x7fff);
            if (lastbit == 0x0001)
            {
                crc = (UInt16)(crc ^ 0xa001);
            }
        }
    }
    return (Byte)(crc & 0xFF);
}

@end
