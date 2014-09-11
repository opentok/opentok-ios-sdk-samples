//
//  TBPublisher.h
//  Lets-Build-OTPublisher
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import <OpenTok/OpenTok.h>
#import "TBExampleVideoView.h"
#import "TBAudioLevelMeter.h"

@interface TBExamplePublisher : OTPublisherKit <TBExampleVideoViewDelegate>

@property(readonly) TBExampleVideoView* view;
@property(nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (retain, nonatomic) TBAudioLevelMeter *audioLevelMeter;
@end
