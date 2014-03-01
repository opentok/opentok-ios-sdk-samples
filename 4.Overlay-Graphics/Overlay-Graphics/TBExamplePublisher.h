//
//  TBPublisher.h
//  Overlay-Graphics
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#import <OpenTok/OpenTok.h>
#import "TBExampleVideoView.h"
@interface TBExamplePublisher : OTPublisherKit <TBExampleVideoViewDelegate>

@property(readonly) TBExampleVideoView* view;

@property(nonatomic, assign) AVCaptureDevicePosition cameraPosition;

@end
