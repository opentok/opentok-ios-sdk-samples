//
//  OTVideoView.h
//  Overlay-Graphics
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenTok/OpenTok.h>

@class TBExampleGLViewRender;
@protocol TBExampleVideoViewDelegate;

/**
 * A generic view hierarchy for viewable objects with video in the OpenTok iOS 
 * SDK.
 */
@interface TBExampleVideoView : OTVideoView <OTVideoRender>

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
@property(readonly, retain) UIView* videoView;

@property(nonatomic, copy) NSString* displayName;

@property(nonatomic) BOOL streamHasVideo;

@property(nonatomic) BOOL streamHasAudio;

- (id)initWithFrame:(CGRect)frame
           delegate:(id<TBExampleVideoViewDelegate>)delegate
               type:(OTVideoViewType)type
        displayName:(NSString*)displayName;
/**
 * Take a snapshot of the current video frame displayed
 *
 * @param block - a block that will be invoked upon a successful image capture
 * with a resulting UIImage
 */

- (void)getImageWithBlock:(void (^)(UIImage* snapshot))block;

@end

@protocol TBExampleVideoViewDelegate <NSObject>

@optional
- (void)videoViewDidToggleCamera:(TBExampleVideoView*)videoView;
- (void)videoView:(TBExampleVideoView*)videoView
publisherWasMuted:(BOOL)publisherMuted;
- (void)videoView:(TBExampleVideoView*)videoView
subscriberVolumeWasMuted:(BOOL)subscriberMuted;

@end
