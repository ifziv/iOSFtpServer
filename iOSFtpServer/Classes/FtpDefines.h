enum {
	pasvftp=0,epsvftp,portftp,lprtftp, eprtftp
};

#define DATASTR(args) [ args dataUsingEncoding:NSUTF8StringEncoding ]

#define SERVER_PORT 2121
#define READ_TIMEOUT -1

#define FTP_CLIENT_REQUEST 0

#define FTP_ANONYMOUS_KEY  @"ftp anonymous"
#define FTP_USERNAME_KEY @"ftp user name"
#define FTP_PASSWORD_KEY  @"ftp password"
#define FTP_PORT_KEY  @"ftp port"
#define ftp_paras_changed_notification  @"ftp_paras_changed_notification"
#define ftp_aes_pwd  @"_ftp_fuck_pwd_"

enum {
	
	clientSending=0, clientReceiving=1, clientQuiet=2,clientSent=3
};
