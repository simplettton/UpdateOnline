//
//  pack.m
//  AirWave
//
//  Created by Macmini on 2017/8/22.
//  Copyright © 2017年 Shenzhen Lifotronic Technology Co.,Ltd. All rights reserved.
//

#import "Pack.h"

typedef void(^NewByteBlock)(NSInteger,NSInteger);
@implementation Pack

/// <summary>
/// 通用打包函数
/// </summary>
/// <param name="cmdid">命令ID</param>
/// <param name="address_enabled">存在地址byte[]高位在前</param>
/// <param name="address">地址</param>
/// <param name="data_enabled">存在数据byte[]</param>
/// <param name="data">数据byte[]高位在前</param>
/// <returns></returns>

+(NSData *)packetWithCmdid:(Byte)cmdid addressEnabled:(BOOL)addrEnabled addr:(NSData *)paddr dataEnabled:(BOOL)dataEnabled data:(NSData *)pdata
{

    Byte *data = (Byte *)[pdata bytes];
    Byte *addr = (Byte *)[paddr bytes];
    
    UInt8 lengthOfData = [pdata length];
    UInt8 lengthOfAddr = [paddr length];
    
    uint8_t *ls = malloc(sizeof(*ls)*100);
    uint8_t *tmpData = malloc(sizeof(*tmpData)*100);
    
    UInt8 length = 1;
    
    if (addrEnabled) {  length += (Byte)lengthOfAddr;   }
    if (dataEnabled) {  length += (Byte)lengthOfData;   }
    
    ls[0] = 0Xaa;
    tmpData[0] = length;
    tmpData[1] = cmdid;
    if(addrEnabled)
    {
        for (int i = 0;i<lengthOfAddr; i++ )
        {
            tmpData[2+i] = addr[i];
        }
    }
    if (dataEnabled)
    {
        for (int i = 0; i<lengthOfData; i++)
        {
            tmpData[2+lengthOfAddr+i] = data[i];
        }
    }
    
    NSData *crcData = [NSData dataWithBytes:tmpData length:2+lengthOfData+lengthOfAddr];
    Byte crc8 = [self getCRC8WithData:crcData];
    tmpData[2+lengthOfAddr+lengthOfData] = crc8;
    
    
    UInt32 lengthOfLs = 1;
    for (int i = 0; i<(lengthOfData+lengthOfAddr+3); i++)
    {
        
        if (tmpData[i] == 0xaa || tmpData[i] == 0x55 || tmpData[i] == 0xcc)
        {
            ls[lengthOfLs] = 0xcc;
            ls[lengthOfLs + 1] = (Byte)(tmpData[i]+1);
            lengthOfLs ++;
        }
        else
        {
            ls[lengthOfLs] = tmpData[i];
        }
        lengthOfLs++;
    }
    
    ls[lengthOfLs] = 0x55;
    lengthOfLs++;
    NSData * packData = [NSData dataWithBytes:ls length:lengthOfLs];
    return packData;
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
+(uint32_t)getCRC32WithData:(NSData *)pdata
{
    //生成码表
    uint crc;
    uint *crc32Table = malloc(sizeof(*crc32Table)*256);;
    for (uint i = 0; i < 256; i++)
    {      
        crc = i;
        for (int j = 8; j > 0; j--)
        {
            if ((crc & 1) == 1)
            {
                crc = (crc >> 1) ^ 0XEDB88320;
            }
            else
            {
                crc >>= 1;
            }
        }
        crc32Table[i] = crc;
    }
    
    uint value = 0xffffffff;
    NSUInteger len = pdata.length;
    Byte *data = (Byte *)[pdata bytes];
    for (int i = 0; i < len; i++)
    {
        value = (value >> 8) ^ crc32Table[(value & 0xFF)^data[i]];
    }
    return value ^ 0xffffffff;
}



@end
