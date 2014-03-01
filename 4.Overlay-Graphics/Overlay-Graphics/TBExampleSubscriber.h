//
//  TBSubscriber.h
//  Overlay-Graphics
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#import <OpenTok/OpenTok.h>
#import "TBExampleVideoView.h"

@interface TBExampleSubscriber : OTSubscriberKit<TBExampleVideoViewDelegate>

@property (readonly) TBExampleVideoView* view;

@end
