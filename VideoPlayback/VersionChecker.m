//
//  VersionChecker.m
//  VideoPlayback
//
//  Created by Victor on 15/07/13.
//
//

#import "VersionChecker.h"
#import "GAI.h"
#include <sys/types.h>
#include <sys/sysctl.h>

@interface VersionChecker() <NSURLConnectionDataDelegate, NSURLConnectionDelegate, UIAlertViewDelegate>

@property (strong, nonatomic) NSMutableData * mutData;
@property (strong, nonatomic) NSURL * downloadUrl;

@end

@implementation VersionChecker

#define appName @"Leitor-iPostal"



- (id)init
{
    self = [super init];
    if (self)
    {
        NSMutableURLRequest * req;
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://ipostal.com.br/api/version"]];
        [req addValue:[self generateUserAgent] forHTTPHeaderField:@"User-Agent"];
        
        NSURLConnection * connection;
        connection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
        [connection scheduleInRunLoop:[NSRunLoop mainRunLoop]
                              forMode:NSDefaultRunLoopMode];
        [connection start];
        NSLog(@"start connection:%@", connection);
    }
    return self;
}


- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"connection didReceiveResponse:%@", response);
    self.mutData = [[NSMutableData alloc] init];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSLog(@"connection didReceiveData");
    [self.mutData appendData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSLog(@"version:%d", [self.mutData length]);
    NSLog(@"version:%@", [[NSString alloc] initWithData:self.mutData encoding:NSUTF8StringEncoding]);
    NSError * error = nil;
    NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:self.mutData options:kNilOptions error:&error];
    if (error)
    {
        NSLog(@"nothing new\n");
    }
    else
    {
        self.downloadUrl = [NSURL URLWithString:[dict objectForKey:@"uri"]];
        [self performSelectorOnMainThread:@selector(displayAlert:) withObject:[dict objectForKey:@"description"] waitUntilDone:NO];
    }
}

- (void) displayAlert:(NSString*)info
{
    UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Chegou uma nova versão!" message:info delegate:self cancelButtonTitle:@"Cancelar" otherButtonTitles:@"Atualizar", nil];
    [alert show];
}

- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString * action;
    if (buttonIndex == 1)
    {
        [[UIApplication sharedApplication] openURL:self.downloadUrl];
        action = @"Update";
    }
    else
    {
        action = @"Cancel";
    }
    [[[GAI sharedInstance] defaultTracker] sendEventWithCategory:@"Call To Update" withAction:action withLabel:appName withValue:nil];
}

- (NSString*)generateUserAgent
{
    NSString* output = [NSString stringWithFormat:@"%@/%@ iOS/%@ %@", appName, [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"], [[UIDevice currentDevice] systemVersion], [self platformStringSlash]];
    
    NSLog(@"user-agent:%@", output);
    return  output;
}


- (NSString*)platformStringSlash
{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);
    if ([platform isEqualToString:@"iPhone1,1"])    return @"iPhone/1G";
    if ([platform isEqualToString:@"iPhone1,2"])    return @"iPhone/3G";
    if ([platform isEqualToString:@"iPhone2,1"])    return @"iPhone/3GS";
    if ([platform isEqualToString:@"iPhone3,1"])    return @"iPhone/4";
    if ([platform isEqualToString:@"iPhone3,3"])    return @"VerizoniPhone/4";
    if ([platform isEqualToString:@"iPhone4,1"])    return @"iPhone/4S";
    if ([platform isEqualToString:@"iPhone5,1"])    return @"iPhone/5(GSM)";
    if ([platform isEqualToString:@"iPhone5,2"])    return @"iPhone/5(GSM+CDMA)";
    if ([platform isEqualToString:@"iPod1,1"])      return @"iPodTouch/1G";
    if ([platform isEqualToString:@"iPod2,1"])      return @"iPodTouch/2G";
    if ([platform isEqualToString:@"iPod3,1"])      return @"iPodTouch/3G";
    if ([platform isEqualToString:@"iPod4,1"])      return @"iPodTouch/4G";
    if ([platform isEqualToString:@"iPod5,1"])      return @"iPodTouch/5G";
    if ([platform isEqualToString:@"iPad1,1"])      return @"iPad";
    if ([platform isEqualToString:@"iPad2,1"])      return @"iPad2/(WiFi)";
    if ([platform isEqualToString:@"iPad2,2"])      return @"iPad2/(GSM)";
    if ([platform isEqualToString:@"iPad2,3"])      return @"iPad2/(CDMA)";
    if ([platform isEqualToString:@"iPad2,4"])      return @"iPad2/(WiFi)";
    if ([platform isEqualToString:@"iPad2,5"])      return @"iPadMini/(WiFi)";
    if ([platform isEqualToString:@"iPad2,6"])      return @"iPadMini/(GSM)";
    if ([platform isEqualToString:@"iPad2,7"])      return @"iPadMini/(GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,1"])      return @"iPad3/(WiFi)";
    if ([platform isEqualToString:@"iPad3,2"])      return @"iPad3/(GSM+CDMA)";
    if ([platform isEqualToString:@"iPad3,3"])      return @"iPad3/(GSM)";
    if ([platform isEqualToString:@"iPad3,4"])      return @"iPad4/(WiFi)";
    if ([platform isEqualToString:@"iPad3,5"])      return @"iPad4/(GSM)";
    if ([platform isEqualToString:@"iPad3,6"])      return @"iPad4/(GSM+CDMA)";
    if ([platform isEqualToString:@"i386"])         return @"Simulator/1";
    if ([platform isEqualToString:@"x86_64"])       return @"Simulator/1";
    return platform;
}

@end
