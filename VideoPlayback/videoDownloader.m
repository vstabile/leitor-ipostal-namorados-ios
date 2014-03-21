//
//  videoDownloader.m
//  CloudReco
//
//  Created by Victor on 03/07/13.
//
//

#import "videoDownloader.h"


@interface videoDownloader() <NSURLConnectionDataDelegate, NSURLConnectionDelegate>

@property (assign, nonatomic) long long videoSize;
@property (strong, nonatomic) NSMutableData *mutData;
@property (nonatomic, copy) void (^progress)(float progress);
@property (nonatomic, copy) void (^completion)(NSData* videoData);
@property (nonatomic, copy) void (^error)(NSString* error);
@end


@implementation videoDownloader

- (void)getVideo:(NSURL*)url progress:(void (^)(float progress))progress completion:(void (^)(NSData* videoData))completion error:(void(^)(NSString* error))error
{
    self.progress = progress;
    self.completion = completion;
    self.error = error;
    NSURLRequest * req;
    req = [NSURLRequest requestWithURL:url];
    
    NSURLConnection * connection;
    connection = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
//    [connection scheduleInRunLoop:[NSRunLoop mainRunLoop]
//                          forMode:NSDefaultRunLoopMode];
    [connection start];
    NSLog(@"start connection:%@", connection);
}

- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSLog(@"connection didReceiveResponse:%@", response);
    self.videoSize = [response expectedContentLength];
    self.mutData = [[NSMutableData alloc] init];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    NSLog(@"connection didReceiveData");
    [self.mutData appendData:data];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.progress((float)[self.mutData length]/self.videoSize);
    });
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.completion([NSData dataWithData:self.mutData]);
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error(@"Você precisa estar conectado à internet para a mágica acontecer.");
}

@end
