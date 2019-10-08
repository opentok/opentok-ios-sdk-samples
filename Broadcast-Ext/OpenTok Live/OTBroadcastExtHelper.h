//
//  OTBroadcastExtHelper.h
//  OpenTok Live
//
//  Created by Sridhar Bollam on 8/5/19.
//  Copyright © 2019 TokBox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

NS_ASSUME_NONNULL_BEGIN

@interface OTBroadcastExtHelper : NSObject
{
    
}

-(instancetype)initWithPartnerId:(NSString *)partnerId
                       sessionId:(NSString *)sessionId
                        andToken:(NSString *)token
                   videoCapturer:(id <OTVideoCapture>)videoCapturer;

-(void)connect;
-(void)disconnect;
- (BOOL)isConnected;

-(void)writeAudioSamples:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
