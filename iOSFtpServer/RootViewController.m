//
//  RootViewController.m
//  iOSFtpServer
//
//  Created by zivInfo on 17/2/10.
//  Copyright © 2017年 xiwangtech.com. All rights reserved.
//

#import "RootViewController.h"

@interface RootViewController ()

@end

@implementation RootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"FTP传文件";
    self.view.backgroundColor = [UIColor whiteColor];
    
    UILabel *ssidLabel = [[UILabel alloc] init];
    ssidLabel.frame = CGRectMake(20, 120, [UIScreen mainScreen].bounds.size.width - 40, 35);
    ssidLabel.backgroundColor = [UIColor clearColor];
    ssidLabel.textAlignment = NSTextAlignmentCenter;
    ssidLabel.textColor = [UIColor grayColor];
    [self.view addSubview:ssidLabel];
    
    UILabel *fontLabel = [[UILabel alloc] init];
    fontLabel.frame = CGRectMake(20, 220, [UIScreen mainScreen].bounds.size.width - 40, 35);
    fontLabel.backgroundColor = [UIColor clearColor];
    fontLabel.textAlignment = NSTextAlignmentCenter;
    fontLabel.textColor = [UIColor grayColor];
    fontLabel.text = [NSString stringWithFormat:@"在电脑或者FTP软件中输入"];
    [self.view addSubview:fontLabel];
    
    self.netLabel = [[UILabel alloc] init];
    self.netLabel.frame = CGRectMake(20, 245, [UIScreen mainScreen].bounds.size.width - 40, 35);
    self.netLabel.backgroundColor = [UIColor clearColor];
    self.netLabel.textAlignment = NSTextAlignmentCenter;
    self.netLabel.textColor = [UIColor blackColor];
    [self.view addSubview:self.netLabel];
    
    UILabel *warnLabel = [[UILabel alloc] init];
    warnLabel.frame = CGRectMake(20, 320, [UIScreen mainScreen].bounds.size.width - 40, 75);
    warnLabel.backgroundColor = [UIColor clearColor];
    warnLabel.textAlignment = NSTextAlignmentCenter;
    warnLabel.textColor = [UIColor grayColor];
    warnLabel.numberOfLines = 0;
    warnLabel.text = [NSString stringWithFormat:@"提示：\nFTP传文件功能已经开启\n传输过程中请勿关闭此页或者锁屏"];
    [self.view addSubview:warnLabel];

    
    
    
    [self initFTPServer];
}

- (void)initFTPServer
{
    NSString *localIPAddress = [ NetworkController localWifiIPAddress ];
    self.netLabel.text = [NSString stringWithFormat:@"ftp://%@:2121", localIPAddress];

    
    NSArray *docFolders = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES );
    self.baseDir = docFolders.lastObject;
    
    // 加载参数 是否匿名、用户名、密码、端口
    [self loadSetting];

    // 启动后有个定时器监听网络状态，加互斥锁防止取值有误
    pthread_mutex_init(&_serverMutex, NULL);
    pthread_mutex_init(&_BSSIDMutex, NULL);
    self.BSSID = @"";
    theServer = nil;
    serverStopedByUser = true;
    wifiStateTimer = nil;
    currentServerState = SERVER_STATE_STOP;
    if ([NetworkController getConnectionType] != 1)
    {
        currentServerState = SERVER_STATE_NOWIFI;
    }

    // 开始监听，除非该页面关闭，否则不停
    [self startListenWifiState];
    
    // 开启FTP服务器。
    [self startFtpServer];

}

#pragma mark - function

-(void)loadSetting
{
    self.isAnonymous = true;
    self.userName = [NSString stringWithFormat:@""];
    self.userPwd = [NSString stringWithFormat:@""];
    self.ftpPort = SERVER_PORT;
    
    NSString *plistPath = savedFilePath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:plistPath])
    {
        NSMutableDictionary* ftpDicInfo = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
        if (ftpDicInfo)
        {
            NSNumber* anonymousNumber = [ftpDicInfo objectForKey:FTP_ANONYMOUS_KEY];
            if (anonymousNumber)
            {
                self.isAnonymous = [anonymousNumber boolValue];
            }
            NSString* userNameStr = [ftpDicInfo objectForKey:FTP_USERNAME_KEY];
            if (userNameStr)
            {
                userNameStr = [AESCrypt decrypt:userNameStr password:ftp_aes_pwd];
                if (userNameStr)
                {
                    self.userName = [[NSString alloc] initWithString:userNameStr];
                }
            }
            NSString* pwdStr = [ftpDicInfo objectForKey:FTP_PASSWORD_KEY];
            if (pwdStr)
            {
                pwdStr = [AESCrypt decrypt:pwdStr password:ftp_aes_pwd];
                if (pwdStr)
                {
                    self.userPwd = [[NSString alloc] initWithString:pwdStr];
                }
            }
            NSNumber* portNumber = [ftpDicInfo objectForKey:FTP_PORT_KEY];
            if (portNumber)
            {
                int port = [portNumber intValue];
                if (port == 0)
                {
                    port = SERVER_PORT;
                }
                self.ftpPort = port;
            }
            
        }
    }
}

NSString *savedFilePath()
{
    NSArray *docFolders = NSSearchPathForDirectoriesInDomains (NSDocumentDirectory, NSUserDomainMask, YES );
    NSString* plistPath = [docFolders.lastObject stringByAppendingPathComponent:@"ftp.plist"];
    return plistPath;
}

-(void)startListenWifiState
{
    [self stopListenWifiState];
    wifiStateTimer = [NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(listenWifiState) userInfo:nil repeats:YES];
}

-(void)stopListenWifiState
{
    if (wifiStateTimer) {
        [wifiStateTimer invalidate];
        wifiStateTimer = nil;
    }
}

-(void)listenWifiState
{
    SERVER_STATE oldState = currentServerState;
    if ([NetworkController getConnectionType] != 1)
    {
        //非wifi网络
        if ([self getServer])
        {
            //网络状态改变了，此时不是用户点击了切换按钮
            serverStopedByUser = false;
        }
        currentServerState = SERVER_STATE_NOWIFI;
        [self stopFtpServer];
    }
    else
    {
        bool needStop = false;
        NSString* bssid = @"";
        id ssid = [NetworkController fetchSSIDInfo];
        if (ssid && [ssid isKindOfClass:[NSDictionary class]])
        {
            //当前wifi网络的BSSID
            bssid = [ssid objectForKey:@"BSSID"];
            
        }
        if ([self getBSSID].length > 0 && bssid && ![bssid isEqualToString:[self getBSSID]])
        {
            //用户在系统设置界面更改了wifi连结点，或者wifi自动切换了连结点，网络环境变化了，需要停止ftp服务
            serverStopedByUser = true;
            needStop = true;
        }
        if (![self getServer])
        {
            //getServer为空说明ftp服务已经停了
            if (!serverStopedByUser && !needStop)
            {
                //既不是用户主动停止也没有改变网络环境，有可能是网络不稳定造成的停止，重启服务
                currentServerState = SERVER_STATE_RUNNING;
                [self startFtpServer];
            }
            else
            {
                currentServerState = SERVER_STATE_STOP;
            }
            
        }
        else
        {
            //getServer不为空说明ftp服务正在运行
            if (needStop)
            {
                //网络环境改变，需要停止服务
                serverStopedByUser = true;
                currentServerState = SERVER_STATE_STOP;
                [self stopFtpServer];
                [self setBSSID:bssid];
            }
            else
            {
                currentServerState = SERVER_STATE_RUNNING;
            }
            
        }
        
    }
    if (oldState != currentServerState)
    {
        //网络状态发生改变，重置View
    }
    
}

#pragma mark - paras for ftpConnection
-(BOOL)getIsAnonymous
{
    return self.isAnonymous;
}
-(NSString*)getFtpUserName
{
    return self.userName;
}
-(NSString*)getFtpPWD
{
    return self.userPwd;
}

-(void)setBSSID:(NSString *)bssid
{
    pthread_mutex_lock(&_BSSIDMutex);
    _BSSID = [[NSString alloc] initWithString:bssid];
    pthread_mutex_unlock(&_BSSIDMutex);
}
-(NSString*)getBSSID
{
    NSString* ret = nil;
    pthread_mutex_lock(&_BSSIDMutex);
    ret = _BSSID;
    pthread_mutex_unlock(&_BSSIDMutex);
    return ret;
}

-(FtpServer*)getServer
{
    FtpServer* ret = nil;
    pthread_mutex_lock(&_serverMutex);
    ret = theServer;
    pthread_mutex_unlock(&_serverMutex);
    return ret;
}
-(void)setServer:(FtpServer*)server
{
    pthread_mutex_lock(&_serverMutex);
    self.theServer = server;
    pthread_mutex_unlock(&_serverMutex);
}
-(void)startFtpServer
{
    if(![self getServer]) {
        FtpServer *aServer = [[ FtpServer alloc ] initWithPort:self.ftpPort withDir:self.baseDir notifyObject:self ];
        [self setServer:aServer];
        aServer.clientEncoding = NSUTF8StringEncoding;
    }
}
- (void)stopFtpServer
{
    if([self getServer]) {
        [theServer stopFtpServer];
        theServer=nil;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
