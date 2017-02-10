//
//  RootViewController.h
//  iOSFtpServer
//
//  Created by zivInfo on 17/2/10.
//  Copyright © 2017年 xiwangtech.com. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <pthread.h>

#import "FtpServer.h"
#import "AESCrypt.h"
#import "NetworkController.h"

typedef enum SERVER_STATE
{
    SERVER_STATE_RUNNING,
    SERVER_STATE_STOP,
    SERVER_STATE_NOWIFI,
    
}SERVER_STATE;

@interface RootViewController : UIViewController
{
    FtpServer	 *theServer;
    SERVER_STATE currentServerState;
    NSString     *baseDir;
    NSTimer      *wifiStateTimer;
    bool         serverStopedByUser;
}

@property (nonatomic, copy) NSString    *baseDir;
@property (nonatomic, retain) FtpServer *theServer;
@property(nonatomic)UILabel      *netLabel;
@property(nonatomic,retain)NSString                   *BSSID;
@property(nonatomic,assign)pthread_mutex_t            serverMutex;
@property(nonatomic,assign)pthread_mutex_t            BSSIDMutex;
@property(nonatomic,assign)BOOL                       isAnonymous;
@property(nonatomic,retain)NSString                   *userName;
@property(nonatomic,retain)NSString                   *userPwd;
@property(nonatomic,assign)int                        ftpPort;

- (void)didReceiveFileListChanged;
- (void)stopFtpServer;
- (void)toggleServerState:(id)sender;
- (BOOL)getIsAnonymous;
- (NSString*)getFtpUserName;
- (NSString*)getFtpPWD;

@end
