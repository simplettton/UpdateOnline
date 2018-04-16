//
//  ViewController.m
//  UpdateOnline
//
//  Created by Macmini on 2017/12/14.
//  Copyright © 2017年 Shenzhen Lifotronic Technology Co.,Ltd. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking.h>
#import <ifaddrs.h>
#import <net/if.h>
#import <SystemConfiguration/CaptiveNetwork.h>

#import "AppDelegate.h"
#import <GCDAsyncSocket.h>
#import <SVProgressHUD.h>
#import "HeaderFile.h"
#import "ViewClickEffect.h"
#import "Pack.h"
#import "Unpack.h"

#define FILEPATH [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject]
#define KPacketTailValue 0x55
typedef NS_ENUM(NSInteger,KCmdids) {
    CMDID_UPGRATE_REQUEST                = 0X9B,
    CMDID_ARM_UPGRATE_PREPARE_COMPLETED  = 0X0D,
    CMDID_ARM_UPGRATE_DATA_REQUEST       = 0X0F,
    CMDID_ARM_WAIT_UPGRATE_TIMEOUT       = 0X10
};
NSString * const kOpenFileNotification = @"KOpenFileNotification";
NSString * const kFileName = @"KFileName";
NSString * const kFilePath = @"KFilePath";
NSString * const kUserInteractionEnabled = @"UserInteractionEnabled";
NSInteger  const MaxDataLength = 1024;

@interface ViewController ()<GCDAsyncSocketDelegate,UIDocumentInteractionControllerDelegate>
@property (nonatomic, strong) GCDAsyncSocket *clientSocket;
@property (nonatomic, strong) NSTimer *connectTimer;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, assign) NSInteger sendTimes;
@property (nonatomic, strong) NSString *documentPath;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSData *binData;

@property (weak, nonatomic) IBOutlet UILabel *fileNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *fileLengthLabel;
@property (weak, nonatomic) IBOutlet ViewClickEffect *connectView;
@property (weak, nonatomic) IBOutlet ViewClickEffect *upgradeView;
@property (weak, nonatomic) IBOutlet UIView *fileView;

@property (weak, nonatomic) IBOutlet UIImageView *connectImageView;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *upgradeButton;

- (IBAction)connectToHost:(id)sender;
- (IBAction)upgrade:(id)sender;
@end

@implementation ViewController
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.connectView.userInteractionEnabled = YES;
    self.upgradeView.userInteractionEnabled = YES;
    //添加手势
    UITapGestureRecognizer * connectGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(connectToHost:)];
    UITapGestureRecognizer * upGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(upgrade:)];
    self.sendTimes = 0;
    [self.connectView addGestureRecognizer:connectGesture];
    [self.upgradeView addGestureRecognizer:upGesture];
    [self configFileView];
    if (!self.binData)
    {
        self.fileView.hidden = YES;
    }
    //这个可以查找 [FilePath getDelegateFilePath] 路径下的所有文件
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager]enumeratorAtPath:FILEPATH];
    for (NSString *fileName in enumerator)
    {
        self.fileName = fileName;
        self.documentPath = [FILEPATH stringByAppendingPathComponent:fileName];
        if (self.documentPath)
        {
            BOOL isDirectory = NO;
            [[NSFileManager defaultManager] fileExistsAtPath:[FILEPATH stringByAppendingPathComponent:fileName] isDirectory:&isDirectory];
            if (!isDirectory)
            {
                NSLog(@"File path is: %@", self.documentPath);
                NSData * resultdata = [[NSData alloc] initWithContentsOfFile:self.documentPath];
                self.binData = resultdata;
                self.fileView.hidden = NO;
                
                [self configFileView];
            }
        }
    }
    
    
    NSUserDefaults *userdefault = [NSUserDefaults standardUserDefaults];
    
    NSString *host = [userdefault objectForKey:@"HostSetting"];
    
    NSString *port = [userdefault objectForKey:@"PortSetting"];
    
    if (host == nil &&port == nil) {
        [userdefault setObject:@"10.10.100.254" forKey:@"HostSetting"];
        [userdefault setObject:@"8080" forKey:@"PortSetting"];
        [userdefault synchronize];
    }
    
    [self reachability];
    
}
- (void)reachability
{
    // 1.获得网络监控的管理者
    AFNetworkReachabilityManager *mgr = [AFNetworkReachabilityManager sharedManager];
    // 2.设置网络状态改变后的处理
    [mgr setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        // 当网络状态改变了, 就会调用这个block
        switch (status) {
            case AFNetworkReachabilityStatusUnknown: // 未知网络
                NSLog(@"网络异常：未知网络");
                break;
            case AFNetworkReachabilityStatusNotReachable: // 没有网络(断网)
            {
                NSLog(@"网络异常：没有网络(断网)");
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"蜂窝移动数据已关闭"
                                                                               message:@"打开蜂窝移动数据或使用Wi-Fi来访问数据。"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction* settingAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    if (@available(iOS 10.0, *)) {
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"App-prefs:root"]options:@{} completionHandler:nil];
                    } else {
                        // Fallback on earlier versions
                    }
                }];
                UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault
                                                                      handler:^(UIAlertAction * action) {}];
                [alert addAction:settingAction];
                [alert addAction:defaultAction];
                [self presentViewController:alert animated:YES completion:^{
                }];
                [SVProgressHUD dismiss];
                break;
            }
            case AFNetworkReachabilityStatusReachableViaWWAN: // 手机自带网络
                NSLog(@"网络状态检测：蜂窝网络");
                break;
            case AFNetworkReachabilityStatusReachableViaWiFi: // WIFI
                NSLog(@"网络状态检测：WiFi");
                break;
        }
    }];
    // 3.开始监控
    [mgr startMonitoring];
}

-(void)configFileView
{
    self.fileNameLabel.text = [NSString stringWithFormat:@"%@",(self.fileName!=nil)?self.fileName:@"App.bin"];
    self.fileLengthLabel.text = [NSString stringWithFormat:@"%luk",(unsigned long)(self.binData?[self.binData length]/1024:0)];
}
-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    self.navigationController.navigationBar.barTintColor = UIColorFromHex(0Xfe9899);
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    
    [self.connectView addObserver:self
                   forKeyPath:kUserInteractionEnabled
                      options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                      context:nil];
    [self.upgradeView addObserver:self
                       forKeyPath:kUserInteractionEnabled
                          options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                          context:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(handleNotification:)
                                                name:kOpenFileNotification
                                              object:nil];
}
-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:YES];
    [SVProgressHUD dismiss];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self.connectView removeObserver:self forKeyPath:kUserInteractionEnabled];
    [self.upgradeView removeObserver:self forKeyPath:kUserInteractionEnabled];
    
}
-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    switch (self.connectView.userInteractionEnabled)
    {
        case YES:
            self.connectButton.titleLabel.textColor = UIColorFromHex(0xFE9899);
            self.connectImageView.image = [UIImage imageNamed:@"internet"];
            break;
        case NO:
            self.connectButton.titleLabel.textColor = UIColorFromHex(0xcdcdcd);
            self.connectImageView.image = [UIImage imageNamed:@"internet_grey"];
            break;
        default:
            break;
    }
    switch (self.upgradeView.userInteractionEnabled)
    {
        case YES:
            self.upgradeButton.titleLabel.textColor = UIColorFromHex(0xFFC94D);
            self.upgradeButton.titleLabel.text = @"升级设备";
            break;
        case NO:

            break;
        default:
            break;
    }
}
#pragma mark - Notification
-(void)handleNotification:(NSNotification *)notification
{
    NSLog(@"File path is: %@", notification.userInfo[kFilePath]);
    self.documentPath = notification.userInfo[kFilePath];
    NSData * resultdata = [[NSData alloc] initWithContentsOfFile:self.documentPath];
    self.binData = resultdata;
    self.fileView.hidden = NO;
    
    //显示状态
    self.fileName = notification.userInfo[kFileName];
    NSString *statusString = [NSString stringWithFormat:@"成功打开文件%@",self.fileName];
    [SVProgressHUD setDefaultStyle:SVProgressHUDStyleLight];

    [self configFileView];
    [SVProgressHUD showSuccessWithStatus:statusString];
    
}

#pragma mark - Command
- (IBAction)connectToHost:(id)sender
{
    AppDelegate *myDelegate =(AppDelegate *) [[UIApplication sharedApplication] delegate];
    
    self.clientSocket = [[GCDAsyncSocket alloc]initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    [SVProgressHUD showWithStatus:@"正在连接设备中..."];
    
    NSError *error = nil;
    
    NSUserDefaults *userdefault = [NSUserDefaults standardUserDefaults];
    
    NSString *host = [userdefault objectForKey:@"HostSetting"];
    
    NSString *port = [userdefault objectForKey:@"PortSetting"];
    
    if (host == nil &&port == nil) {
        [userdefault setObject:myDelegate.host forKey:@"HostSetting"];
        [userdefault setObject:myDelegate.port forKey:@"PortSetting"];
        [userdefault synchronize];
    }
    
    
    self.connected = [self.clientSocket connectToHost:host onPort:[port integerValue] viaInterface:nil withTimeout:-1 error:&error];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL isWIFI = [self isWiFiEnabled];
        if (!isWIFI) {//如果WiFi没有打开，作出弹窗提示
            [SVProgressHUD dismiss];
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"无法连接设备"
                                                                           message:@"Wi-Fi已关闭，请打开Wi-Fi以连接设备"
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* settingAction = [UIAlertAction actionWithTitle:@"设置" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (@available(iOS 10.0, *)) {
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"App-prefs:root"]options:@{} completionHandler:nil];
                } else {
                    // Fallback on earlier versions
                }
            }];
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault
                                                                  handler:^(UIAlertAction * action) {}];
            [alert addAction:settingAction];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:^{
            }];
        }
    });
}

- (IBAction)upgrade:(id)sender
{
    if(self.connected)
    {
        if (self.binData)
        {

            [self sendUpgrateRequest];
            [SVProgressHUD showWithStatus:@"正在请求进入升级模式…"];
//            self.connectView.userInteractionEnabled = NO;
//            self.upgradeView.userInteractionEnabled = NO;
            dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC));
            dispatch_after(delayTime, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self sendUpgrateRequest];
            });
        }else
        {
            [SVProgressHUD showErrorWithStatus:@"没有找到升级包"];
            [SVProgressHUD dismissWithDelay:1];
        }
    }else
    {
        [SVProgressHUD showErrorWithStatus:@"设备未连接"];
        [SVProgressHUD dismissWithDelay:1];
    }
}
-(void)sendUpgrateRequest
{
    NSInteger crc32 = [self getCRC32WithData:self.binData];
    NSInteger length = [self.binData length];
    NSData *combinedData = [self combineData:length withCrc32:crc32];
    
    [self.clientSocket writeData:[Pack packetWithCmdid:CMDID_UPGRATE_REQUEST
                                        addressEnabled:NO
                                                  addr:nil
                                           dataEnabled:YES
                                                  data:combinedData]
                     withTimeout:-1
                             tag:1000];
}
#pragma mark - GCDAsyncSocketDelegate
-(void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
//    [self addTimer];
    NSLog(@"连接成功");
    [SVProgressHUD showSuccessWithStatus:@"连接成功"];
    [SVProgressHUD dismissWithDelay:1];
//    [self.clientSocket readDataWithTimeout:- 1 tag:0];
    [sock readDataToData:[self dataWithByte:KPacketTailValue] withTimeout:-1 tag:0];
    self.connectView.userInteractionEnabled = NO;
}
-(void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    NSLog(@"连接失败 errot:%@",err);
    [SVProgressHUD showErrorWithStatus:@"断开连接"];
    [SVProgressHUD dismissWithDelay:1];
    self.connectView.userInteractionEnabled = YES;
}
-(void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
//    if (tag ==1111)
//    {
//        NSLog(@"升级成功");
//        [SVProgressHUD showSuccessWithStatus:@"升级成功"];
//        self.connectView.userInteractionEnabled = YES;
//        self.upgradeView.userInteractionEnabled = YES;
//    }
//    else if(tag == 555){
//        NSLog(@"整包数据写入成功");
//    }
}
-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
//    Byte *bytess = (Byte *)[data bytes];
//    for (int i =0; i<[data length]; i++)
//    {
//        NSLog(@"[%d]=%x",i,bytess[i]);
//    }
    NSData *receivedData = [Unpack unpackData:data];
    if (receivedData !=nil)
    {
        Byte* bytes =(Byte *) [receivedData bytes];
        Byte cmdid = bytes[0];
        switch (cmdid)
        {
                //准备升级完毕
            case CMDID_ARM_UPGRATE_PREPARE_COMPLETED:
                [SVProgressHUD showSuccessWithStatus:@"进入升级模式完毕"];
                [SVProgressHUD dismissWithDelay:1];
                self.connectView.userInteractionEnabled = NO;
                self.upgradeView.userInteractionEnabled = NO;
                break;
                //请求升级数据
            case CMDID_ARM_UPGRATE_DATA_REQUEST:
                if (self.binData)
                {
//                    //1.发送整个包
//                    NSLog(@"--------------");
//                    NSString *progress = [NSString stringWithFormat:@"升级中…"];
//                    [SVProgressHUD showWithStatus:progress];
//                    [self.clientSocket writeData:self.binData withTimeout:-1 tag:555];
                    
                    //2.拆包发送
                    NSInteger packNumber = [self.binData length]/MaxDataLength;
                    NSInteger leftDataLength = [self.binData length]%MaxDataLength;
                     NSString *progress = [NSString stringWithFormat:@"升级中…%ld%%",self.sendTimes*100/packNumber];
                     [SVProgressHUD showWithStatus:progress];
                    if (self.sendTimes < packNumber)
                    {
    
                        NSData *data = [self.binData subdataWithRange:NSMakeRange(self.sendTimes*MaxDataLength, MaxDataLength)];
                        [self.clientSocket writeData:data withTimeout:-1 tag:0];
                        self.sendTimes++;
                    }else if(self.sendTimes == packNumber)
                    {
                        //发送数据无法整除 分解包的长度
                        if (leftDataLength != 0)
                        {
                            NSData *data = [self.binData subdataWithRange:NSMakeRange(self.sendTimes*MaxDataLength, leftDataLength)];
                            [self.clientSocket writeData:data withTimeout:-1 tag:1111];
                        }
                    }
                    NSLog(@"time = %ld",(long)self.sendTimes);
                    if (self.sendTimes == packNumber)
                    {
                        [SVProgressHUD showSuccessWithStatus:@"升级成功"];
                        self.connectView.userInteractionEnabled = YES;
                        self.upgradeView.userInteractionEnabled = YES;
                    }
                }
                break;
                //升级信息返回超时
            case CMDID_ARM_WAIT_UPGRATE_TIMEOUT:
                [SVProgressHUD showErrorWithStatus:@"升级超时"];
                break;
            default:
                break;
        }
    }

    [sock readDataToData:[self dataWithByte:KPacketTailValue] withTimeout:-1 tag:0];
}
#pragma mark - Private Method
-(uint32_t)getCRC32WithData:(NSData *)pdata
{
    NSLog(@"length = %lu",(unsigned long)[pdata length]);
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
                crc = (crc >> 1) ^ 0xEDB88320;
            }
            else
            {
                crc >>= 1;
            }
        }
        crc32Table[i] = crc;
    }
    
    uint value = 0xffffffff;
    NSUInteger len = [pdata length];
    Byte *data = (Byte *)[pdata bytes];

    for (int i = 0; i < len; i++)
    {
        value = (value >> 8) ^ crc32Table[(value & 0xFF)^data[i]];
    }
    return value ^ 0xffffffff;
}
-(NSData *)combineData:(NSUInteger)dataLength withCrc32:(NSUInteger)crc
{
    Byte b1=dataLength & 0xff;
    Byte b2=(dataLength>>8) & 0xff;
    Byte b3=(dataLength>>16) & 0xff;
    Byte b4=(dataLength>>24) & 0xff;
    
    Byte b5=crc & 0xff;
    Byte b6=(crc>>8) & 0xff;
    Byte b7=(crc>>16) & 0xff;
    Byte b8=(crc>>24) & 0xff;
    Byte byte[] = {b1,b2,b3,b4,b5,b6,b7,b8};
    
    NSData *data = [NSData dataWithBytes:byte length:sizeof(byte)];
    return data;
}
-(NSData*) dataWithByte:(Byte)value
{
    NSData *data = [NSData dataWithBytes:&value length:1];
    return data;
}
- (BOOL) isWiFiEnabled
{
    NSCountedSet * cset = [[NSCountedSet alloc] init];
    struct ifaddrs *interfaces;
    if( ! getifaddrs(&interfaces) ) {
        for( struct ifaddrs *interface = interfaces; interface; interface = interface->ifa_next) {
            if ( (interface->ifa_flags & IFF_UP) == IFF_UP ) {
                [cset addObject:[NSString stringWithUTF8String:interface->ifa_name]];
            }
        }
    }
    return [cset countForObject:@"awdl0"] > 1 ? YES : NO;
}
@end
