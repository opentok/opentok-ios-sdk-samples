//
//  TBSubscriber.h
//  Lets-Build-OTPublisher
//
//  Created by Charley Robinson on 12/16/13.
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import <OpenTok/OpenTok.h>

@interface TBExampleSubscriber : OTSubscriberKit

@property (readonly) UIView* view;

@end

@protocol TBExampleSubscriberDelegate <OTSubscriberKitDelegate>

/**
 * Notifies the controller for this subscriber that video is being received.
 */
- (void)subscriberVideoDataReceived:(TBExampleSubscriber*)subscriber;

@end
