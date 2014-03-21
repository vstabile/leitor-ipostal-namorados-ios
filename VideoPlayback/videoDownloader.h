//
//  videoDownloader.h
//  CloudReco
//
//  Created by Victor on 03/07/13.
//
//

#import <Foundation/Foundation.h>


@interface videoDownloader : NSObject
- (void)getVideo:(NSURL*)url progress:(void (^)(float progress))progress completion:(void (^)(NSData* videoData))completion error:(void(^)(NSString* error))error;


@end
