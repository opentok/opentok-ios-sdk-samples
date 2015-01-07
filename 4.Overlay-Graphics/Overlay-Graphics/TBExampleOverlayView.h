//
//  OTOverlayView.h
//  Overlay-Graphics
//
//  Copyright (c) 2014 Tokbox, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TBExampleOverlayButton.h"

#define OVERLAY_NAME_MIN_WIDTH 50
#define OVERLAY_MIN_WIDTH 150
#define OVERLAY_CONTROL_BAR_HEIGHT 43
#define OVERLAY_BUTTON_WIDTH_SM 60 //75
#define OVERLAY_BUTTON_WIDTH_LG 60 //90
#define OVERLAY_HIDE_TIME_MS 5000
#define OVERLAY_LOGO_HIDE_TIME_MS 5000
#define OVERLAY_TOOLTIP_HIDE_TIME_MS 2000

typedef enum {
    TBExampleOverlayViewTypeSubscriber = 0,
    TBExampleOverlayViewTypePublisher  = 1
} TBExampleOverlayViewType;

@protocol TBExampleOverlayViewDelegate;

@interface TBExampleOverlayView : UIView <TBExampleOverlayButtonDelegate>

@property (nonatomic, assign) id<TBExampleOverlayViewDelegate> delegate;
@property (nonatomic, retain) NSString* displayName;
@property (nonatomic, setter = setStreamHasVideo:) BOOL streamHasVideo;
@property (nonatomic, setter = setStreamHasAudio:) BOOL streamHasAudio;
@property (nonatomic, retain) UIView* toolbarView;

- (id)initWithFrame:(CGRect)frame 
        overlayType:(TBExampleOverlayViewType)type 
        displayName:(NSString*)displayName
           delegate:(id<TBExampleOverlayViewDelegate>)delegate;

- (void)toggleCamera;

- (void)muted:(BOOL)mute;

- (void)showOverlay:(UITapGestureRecognizer*)gestureRecognizer;

- (void)startArchiveAnimation;

- (void)stopArchiveAnimation;

- (void)showVideoMayDisableWarning;

- (void)showVideoDisabled;

- (void)resetView;
@end

@protocol TBExampleOverlayViewDelegate <NSObject>

@optional
- (void)overlayViewDidToggleCamera:(TBExampleOverlayView*)overlayView;
- (void)overlayView:(TBExampleOverlayView*)overlay publisherWasMuted:(BOOL)publisherMuted;
- (void)overlayView:(TBExampleOverlayView*)overlay subscriberVolumeWasMuted:(BOOL)subscriberMuted;

@end