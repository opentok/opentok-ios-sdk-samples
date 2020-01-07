//
//  OTAVMultiCamSession.h
//  Custom-Video-Driver
//
//  Created by Sridhar Bollam on 12/17/19.
//  Copyright © 2019 TokBox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OTAVMultiCamSession : NSObject

@property(nonatomic, strong) AVCaptureMultiCamSession *avCaptureMultiCamSession;
@property(nonatomic, strong) dispatch_queue_t capturer_queue;

+ (id)sharedInstance;
- (void)checkSystemCost;
@end

NS_ASSUME_NONNULL_END
