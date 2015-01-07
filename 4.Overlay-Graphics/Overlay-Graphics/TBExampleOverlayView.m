//
//  OTOverlayView.m
//  Overlay-Graphics
//
//  Copyright (c) 2014 Tokbox, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

#import "TBExampleOverlayView.h"
#import "TBExampleOverlayButton.h"

@implementation TBExampleOverlayView
{
    TBExampleOverlayViewType _type;
    NSString* _displayName;
    
    NSTimer* _hideOverlayTimer;
    NSTimer* _hideLogoTimer;
    
    int _numButtons;
    int _totalButtonsWidth;
    int _buttonWidth;

    CGRect crLogoHide;
    CGRect crLogoShow;
    CGRect frameLogoHide;
    CGRect frameLogoShow;
    
    UIView* _controlBar;
    TBExampleOverlayButton* _muteButton;
    TBExampleOverlayButton* _switchCameraButton;
    TBExampleOverlayButton* _volumeButton;
    UIImageView *_archiveImgView;
    UILabel* _nameLabel;

    UIImageView *_videoMayDisableImgView;
    UIImageView *_videoDisabledImgView;
    
    BOOL _subscriberMuted;
    BOOL _publisherMuted;
    
    BOOL _streamHasVideo;
    BOOL _streamHasAudio;
}

@synthesize delegate = _delegate;
@synthesize displayName = _displayName;
@synthesize streamHasVideo = _streamHasVideo;
@synthesize streamHasAudio = _streamHasAudio;
@synthesize toolbarView = _controlBar;

- (void)drawRect:(CGRect)rect
{
    if (_type == TBExampleOverlayViewTypePublisher) {
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextClearRect(ctx, rect);
        
        CGContextSetLineWidth(ctx, 1.0f);
        CGContextSetShouldAntialias(ctx, NO);
        
        CGContextStrokePath(ctx);
    }
}

- (void)layoutOverlay
{
    float insetOffsetRatio = 0.2;
    float buttonAspectRatio =
        (float)_buttonWidth / (float)OVERLAY_CONTROL_BAR_HEIGHT;
    buttonAspectRatio *= 0.7; // "adjust" the aspect ratio :-)
    float edgeInsetsOffsetLR = _buttonWidth * insetOffsetRatio;
    float edgeInsetsOffsetTB =
        buttonAspectRatio * edgeInsetsOffsetLR * insetOffsetRatio;
    
    UIEdgeInsets controlButtonEdgeInsets = UIEdgeInsetsMake(edgeInsetsOffsetTB,
                                                            edgeInsetsOffsetLR,
                                                            edgeInsetsOffsetTB,
                                                            edgeInsetsOffsetLR);

    //control bar at bottom
    _controlBar.frame =
    CGRectMake(0,
               self.frame.size.height - OVERLAY_CONTROL_BAR_HEIGHT + 0.5,
               self.frame.size.width,
               OVERLAY_CONTROL_BAR_HEIGHT);
    
    //name in control bar
    _nameLabel.frame =
    CGRectMake(18,
                0,
               ((self.frame.size.width - _totalButtonsWidth - 18) >
                OVERLAY_NAME_MIN_WIDTH) ?
               (self.frame.size.width - _totalButtonsWidth - 18) : 0,
                OVERLAY_CONTROL_BAR_HEIGHT);
    
    //buttons in control bar
    switch (_type) {
        case TBExampleOverlayViewTypePublisher:
                        
            _switchCameraButton.frame =
            CGRectMake(self.frame.size.width - _buttonWidth,
                       0,
                       _buttonWidth,
                       OVERLAY_CONTROL_BAR_HEIGHT);
            [_switchCameraButton setImageEdgeInsets:controlButtonEdgeInsets];
            
            _muteButton.frame =
            CGRectMake(self.frame.size.width - (_numButtons * _buttonWidth),
                       0,
                       _buttonWidth,
                       OVERLAY_CONTROL_BAR_HEIGHT);
            [_muteButton setImageEdgeInsets:controlButtonEdgeInsets];

            _archiveImgView.frame =
            CGRectMake(self.frame.size.width - (_numButtons * _buttonWidth) - 40,
                       0,
                       30,
                       OVERLAY_CONTROL_BAR_HEIGHT);
            break;
            
        case TBExampleOverlayViewTypeSubscriber:
            
            _volumeButton.frame =
            CGRectMake(self.frame.size.width - OVERLAY_BUTTON_WIDTH_SM,
                       0,
                       OVERLAY_BUTTON_WIDTH_SM,
                       OVERLAY_CONTROL_BAR_HEIGHT);
            [_volumeButton setImageEdgeInsets:controlButtonEdgeInsets];
            
            _videoMayDisableImgView.frame =
            CGRectMake(self.frame.size.width - 50,
                       self.frame.size.height - OVERLAY_CONTROL_BAR_HEIGHT - 50,
                       32,
                       32);
            _videoDisabledImgView.frame = _videoMayDisableImgView.frame;
            break;
    }
    
    [self setNeedsDisplay];
}

- (void)setNumberOfButtons
{
    //figure out if we need to show the switch camera button :)
    BOOL _frontCamAvail =
    [UIImagePickerController
     isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront];

    _numButtons = 0;
    
    if (_type == TBExampleOverlayViewTypePublisher) {
        
        // Unconditionally count mute button as available
        _numButtons++;
        
        if (_frontCamAvail && _streamHasVideo) {
            _switchCameraButton.hidden = NO;
            _numButtons++;
        } else {
            _switchCameraButton.hidden = YES;
        }
        
    } else if (_type == TBExampleOverlayViewTypeSubscriber && _streamHasAudio) {
        _numButtons++;
    }
}

- (id)initWithFrame:(CGRect)frame 
        overlayType:(TBExampleOverlayViewType)type 
        displayName:(NSString*)displayName
           delegate:(id<TBExampleOverlayViewDelegate>)delegate
{
    if (self = [super initWithFrame:frame]) {

        _delegate = delegate;
        _type = type;
        _displayName = displayName;
        
        self.backgroundColor = [UIColor clearColor];
        
        //control bar at bottom
        _controlBar = [[UIView alloc] initWithFrame:CGRectZero];
        [_controlBar setBackgroundColor:[UIColor
                                         colorWithRed:0.0
                                         green:0.0
                                         blue:0.0
                                         alpha:0.6]];
        
        //publisher buttons
        //mute button
        _muteButton = [[TBExampleOverlayButton alloc]
                       initWithFrame:CGRectZero
                   overlayButtonType:TBExampleOverlayButtonTypeMuteButton
                            delegate:self];
        
        //switch camera button
        _switchCameraButton =
        [[TBExampleOverlayButton alloc]
                    initWithFrame:CGRectZero
                overlayButtonType:TBExampleOverlayButtonTypeSwitchCameraButton
                         delegate:self];

        //archive image view
        _archiveImgView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _archiveImgView.image = [UIImage imageNamed:@"archiving_off-Small.png"];
        _archiveImgView.contentMode = UIViewContentModeCenter;
        
        //subscriber buttons
        _volumeButton = [[TBExampleOverlayButton alloc]
                         initWithFrame:CGRectZero
                     overlayButtonType:TBExampleOverlayButtonTypeVolumeButton
                              delegate:self];
        
        //name of publisher/subscriber
        _nameLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _nameLabel.backgroundColor = [UIColor clearColor];
        _nameLabel.font = [UIFont boldSystemFontOfSize:12.0f];
        _nameLabel.textColor = [UIColor whiteColor];
        _nameLabel.text = _displayName;
        _nameLabel.textAlignment = NSTextAlignmentLeft;
        _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
        
        //add the controls to the control bar
        [_controlBar addSubview:_nameLabel];
        
        if (_type == TBExampleOverlayViewTypePublisher) {
            [_controlBar addSubview:_muteButton];
            [_controlBar addSubview:_switchCameraButton];
            [_controlBar addSubview:_archiveImgView];
            _muteButton.enabled = YES;
        } else if (_type == TBExampleOverlayViewTypeSubscriber) {
            [_controlBar addSubview:_volumeButton];
            _volumeButton.enabled = YES;
            
            _videoMayDisableImgView = [[UIImageView alloc] init];
            _videoDisabledImgView = [[UIImageView alloc] init];
            [self addSubview:_videoMayDisableImgView];
            [self addSubview:_videoDisabledImgView];

            _videoMayDisableImgView.image =
            [UIImage imageNamed:@"midCongestion.png"];
            _videoDisabledImgView.image =
            [UIImage imageNamed:@"highCongestion.png"];

            _videoMayDisableImgView.hidden = YES;
            _videoDisabledImgView.hidden = YES;
        }
        
        [self setNumberOfButtons];
        
        //add everything to the overlay view (we set the frames later)
        [self addSubview:_controlBar];

        
        [self layoutOverlay];
        
        self.alpha = 0.0;
    }
    
    return self;
}

- (void)dealloc {
    [_controlBar removeFromSuperview];
    [_controlBar release];

    [_muteButton removeFromSuperview];
    [_muteButton release];
    
    [_switchCameraButton removeFromSuperview];
    [_switchCameraButton release];
    
    [_archiveImgView removeFromSuperview];
    [_archiveImgView release];
    
    [_volumeButton removeFromSuperview];
    [_volumeButton release];
    
    [_nameLabel removeFromSuperview];
    [_nameLabel release];

    [_hideOverlayTimer release];
    [_hideLogoTimer release];
    [_controlBar release];
    [super dealloc];
}

- (void)setDisplayName:(NSString *)displayName 
{
    _displayName = displayName;
    _nameLabel.text = displayName;
}

- (void)setStreamHasVideo:(BOOL)streamHasVideo
{
    _streamHasVideo = streamHasVideo;    
    
    if (_type == TBExampleOverlayViewTypePublisher) {
        [_switchCameraButton setHidden:!streamHasVideo];
    }
    
    [self setNumberOfButtons];
    
    [self layoutOverlay];
}

- (void)setStreamHasAudio:(BOOL)streamHasAudio
{
    _streamHasAudio = streamHasAudio;
    
    [self setNumberOfButtons];
    
    if (_type == TBExampleOverlayViewTypePublisher) {
        // Don't hide the mute button: we can enable/disable audio freely
        //[_muteButton setHidden:!streamHasAudio];
    } else if (_type == TBExampleOverlayViewTypeSubscriber) {
        [_volumeButton setHidden:!streamHasAudio];
    }
    
    [self layoutOverlay];
}

- (void)showOverlay:(UITapGestureRecognizer*)gestureRecognizer
{        

    if (_hideOverlayTimer) {
        [_hideOverlayTimer invalidate];
        _hideOverlayTimer = nil;
    }
    
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:1.0];
    [UIView setAnimationDelegate:self];
    self.alpha = 1.0;
    [UIView commitAnimations];
    
    _hideOverlayTimer = [[NSTimer
                    scheduledTimerWithTimeInterval:OVERLAY_HIDE_TIME_MS/1000
                                            target:self
                                          selector:@selector(hideOverlay:)
                                          userInfo:nil
                                           repeats:NO] retain];
}

- (void)hideOverlay:(NSTimer*)timer
{
    //only allow the overlay to be hidden if we're not currently touching things
    if (!_muteButton.highlighted &&
        !_switchCameraButton.highlighted &&
        !_volumeButton.highlighted) {
        
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:1.0];
        [UIView setAnimationDelegate:self];
        self.alpha = 0.0;
        [UIView commitAnimations];
        
    } else {
        [self showOverlay:nil];
    }
}

- (void)setFrame:(CGRect)frame
{
    frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    
    [super setFrame:frame];
        
    if (self.frame.size.width >= (OVERLAY_BUTTON_WIDTH_LG * _numButtons) +
        OVERLAY_NAME_MIN_WIDTH + _nameLabel.frame.origin.x) {
        _buttonWidth = OVERLAY_BUTTON_WIDTH_LG;
    } else {
        if (self.frame.size.width >= (OVERLAY_BUTTON_WIDTH_SM * _numButtons) +
            OVERLAY_NAME_MIN_WIDTH + _nameLabel.frame.origin.x) {
            _buttonWidth = OVERLAY_BUTTON_WIDTH_SM;
        } else {
            _buttonWidth = (self.frame.size.width / 2);
        }
    }    
        
    switch (_type) {
        case TBExampleOverlayViewTypePublisher:
            
            _totalButtonsWidth = _buttonWidth * _numButtons;
            
            break;
            
        case TBExampleOverlayViewTypeSubscriber:
            
            _totalButtonsWidth = OVERLAY_BUTTON_WIDTH_SM;
            
            break;
    }
    
    [self layoutOverlay];
}

- (void)overlayButtonWasSelected:(TBExampleOverlayButton *)button
{    
    if (button == _muteButton) {
        _publisherMuted = button.selected;
            
        if ([_delegate respondsToSelector:
             @selector(overlayView:publisherWasMuted:)]) {
            [_delegate overlayView:self publisherWasMuted:_publisherMuted];
        }
        
    } else if (button == _switchCameraButton) {
        
        if ([_delegate respondsToSelector:
             @selector(overlayViewDidToggleCamera:)]) {
            [_delegate overlayViewDidToggleCamera:self];
        }

    } else if (button == _volumeButton) {
        _subscriberMuted = button.selected;
        
        if ([_delegate respondsToSelector:
             @selector(overlayView:subscriberVolumeWasMuted:)]) {
            [_delegate overlayView:self
          subscriberVolumeWasMuted:_subscriberMuted];
        }
    }
}

- (void)toggleCamera 
{
    //programmatically touch our switch camera button
    if (_type == TBExampleOverlayViewTypePublisher && _numButtons > 1) {
        [_switchCameraButton
         sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)muted:(BOOL)mute
{
    TBExampleOverlayButton* button;
    
    if (_type == TBExampleOverlayViewTypePublisher) {
        button = _muteButton;
    } else if (_type == TBExampleOverlayViewTypeSubscriber) {
        button = _volumeButton;
    } else {
        button = nil; //?
    }
    
    if (mute) {
        if (!button.selected) {
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
    } else {
        if (button.selected) {
            [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        }
    }
}

- (void)startArchiveAnimation
{
    UIImage *imageOne = [UIImage imageNamed:@"archiving_on-10.png"];
    UIImage *imageTwo = [UIImage imageNamed:@"archiving_pulse-Small.png"];
    NSArray *imagesArray = [NSArray arrayWithObjects:imageOne, imageTwo, nil];
    _archiveImgView.animationImages = imagesArray;
    _archiveImgView.animationDuration = 1.0f;
    _archiveImgView.animationRepeatCount = 0;
    [_archiveImgView startAnimating];
  
}
- (void)stopArchiveAnimation
{
    [_archiveImgView stopAnimating];
    _archiveImgView.animationImages = nil;
}

- (void)showVideoMayDisableWarning
{
    _videoMayDisableImgView.hidden = NO;
    _videoDisabledImgView.hidden = YES;
    self.alpha = 1.0f;
}

- (void)showVideoDisabled
{
    _videoMayDisableImgView.hidden = YES;
    _videoDisabledImgView.hidden = NO;
    self.alpha = 1.0f;
}

- (void)resetView
{
    _videoMayDisableImgView.hidden = YES;
    _videoDisabledImgView.hidden = YES;
    self.alpha = 0.0f;
}

@end
