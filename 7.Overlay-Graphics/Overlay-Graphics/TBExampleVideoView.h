//
//  OTVideoView.h
//  Overlay-Graphics
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenTok/OpenTok.h>
#import "TBExampleVideoRender.h"
#import "TBAudioLevelMeter.h"

typedef enum {
    OTVideoViewTypeSubscriber,
    OTVideoViewTypePublisher
} OTVideoViewType;

@class TBExampleGLViewRender,TBExampleOverlayView;
@protocol TBExampleVideoViewDelegate;

/**
 * A generic view hierarchy for viewable objects with video in the OpenTok iOS 
 * SDK.
 */
@interface TBExampleVideoView : UIView <OTVideoRender>

/**
 * This view holds the bottom bar of video panels. Included is a
 * nameplate showing the stream's name, and buttons for muting tracks
 * and (for a publisher) switching the camera.
 */
@property(readonly, retain) UIView* toolbarView;

/**
 * This view contains the video track for a stream, when available.
 * For subscribers, this view renders frames of the stream.
 * For publishers, this view renders frames as they are encoded to a stream.
 */
@property(readonly, retain) TBExampleVideoRender* videoView;

@property(nonatomic, copy) NSString* displayName;

@property(nonatomic) BOOL streamHasVideo;

@property(nonatomic) BOOL streamHasAudio;

@property(nonatomic, retain) TBExampleOverlayView* overlayView;

@property (retain, nonatomic) TBAudioLevelMeter *audioLevelMeter;

@property (retain, nonatomic) UIView *audioOnlyView;

- (id)initWithFrame:(CGRect)frame
           delegate:(id<TBExampleVideoViewDelegate>)delegate
               type:(OTVideoViewType)type
        displayName:(NSString*)displayName;

@end

@protocol TBExampleVideoViewDelegate <NSObject>

@optional
- (void)videoViewDidToggleCamera:(TBExampleVideoView*)videoView;
- (void)videoView:(TBExampleVideoView*)videoView
publisherWasMuted:(BOOL)publisherMuted;
- (void)videoView:(TBExampleVideoView*)videoView
subscriberVolumeWasMuted:(BOOL)subscriberMuted;

@end
