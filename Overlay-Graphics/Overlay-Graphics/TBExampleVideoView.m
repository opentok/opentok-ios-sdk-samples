//
//  OTVideoView.m
//  Overlay-Graphics
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#define HEADSET_VEW_TAG 300
#define SILHOUETTE_VEW_TAG 400

#import "TBExampleVideoView.h"
#import "TBExampleOverlayView.h"
#import "TBExampleUnderlayView.h"
#import "TBExampleVideoRender.h"

@interface TBExampleVideoView() <TBExampleOverlayViewDelegate>

@property(nonatomic, assign) id<TBExampleVideoViewDelegate> delegate;
@property(nonatomic, retain) TBExampleUnderlayView* underlayView;
@property(nonatomic, retain) UIView* loadingView;
@property(nonatomic) CGSize videoDimensions;
@property(nonatomic, assign) OTStream* stream;

@end

@implementation TBExampleVideoView {
    OTVideoViewType _type;
    UIView* _videoViewHolder;
    CGFloat _lastScale;
    CGPoint _lastPoint;
    UIActivityIndicatorView* _activityIndicatorView;
    UILabel* _lblLoading;
    TBExampleVideoRender* _videoView;

}

@synthesize delegate = _delegate;
@synthesize videoView = _videoView;
@synthesize underlayView = _underlayView;
@synthesize loadingView = _loadingView;
@synthesize overlayView = _overlayView;
@synthesize streamHasVideo = _streamHasVideo;
@synthesize streamHasAudio = _streamHasAudio;
@dynamic toolbarView;
@synthesize videoDimensions = _videoDimensions;
@synthesize stream = _stream;

- (id)initWithFrame:(CGRect)frame 
           delegate:(id<TBExampleVideoViewDelegate>)delegate
               type:(OTVideoViewType)type
        displayName:(NSString*)displayName
{
    
    if (self = [super initWithFrame:frame]) {
        _delegate = delegate;
        
        //default to YES
        _streamHasVideo = YES;
        _streamHasAudio = YES;
        _type = type;
        
        self.backgroundColor = [UIColor blackColor];
        
        _videoViewHolder = [[UIView alloc]
                            initWithFrame:CGRectMake(0, 0,
                                                     frame.size.width,
                                                     frame.size.height)];
        
        _videoView = [[TBExampleVideoRender alloc]
                      initWithFrame:CGRectMake(0, 0,
                                               frame.size.width,
                                               frame.size.height)];
        _videoView.backgroundColor = [UIColor blackColor];
        
        [_videoViewHolder addSubview:_videoView];
        
        _loadingView = [[UIView alloc]
                        initWithFrame:CGRectMake(0, 0,
                                                 frame.size.width,
                                                 frame.size.height)];
        _loadingView.backgroundColor = [UIColor colorWithHue:0
                                                  saturation:0
                                                  brightness:.13
                                                       alpha:1];
                
        _activityIndicatorView =
        [[UIActivityIndicatorView alloc]
         initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [_activityIndicatorView startAnimating];
        
        _lblLoading = [[UILabel alloc]
                       initWithFrame:CGRectMake(0, 0,
                                                self.frame.size.width, 30)];
        _lblLoading.backgroundColor = [UIColor clearColor];
        _lblLoading.textColor = [UIColor whiteColor];
        _lblLoading.textAlignment = NSTextAlignmentCenter;
        _lblLoading.font = [UIFont fontWithName:@"Helvetica-Neue" size:16.0];
        _lblLoading.text = @"Loading . . .";
        _lblLoading.numberOfLines = 1;
        _lblLoading.lineBreakMode = NSLineBreakByWordWrapping;
        [_lblLoading sizeToFit];
        
        [_loadingView addSubview:_activityIndicatorView];
        [_loadingView addSubview:_lblLoading];
        
        TBExampleOverlayViewType overlayType =
        (_type == OTVideoViewTypePublisher) ?
        TBExampleOverlayViewTypePublisher : TBExampleOverlayViewTypeSubscriber;
        
        _underlayView = [[TBExampleUnderlayView alloc]
                         initWithFrame:CGRectMake(0, 0,
                                                  frame.size.width,
                                                  frame.size.height)];
        [_underlayView setAudioActive:_streamHasAudio];
        
        _overlayView = [[TBExampleOverlayView alloc]
                        initWithFrame:CGRectMake(0, 0,
                                                 frame.size.width,
                                                 frame.size.height)
                        overlayType:overlayType
                        displayName:displayName
                        delegate:self];
        
        [_overlayView setStreamHasAudio:_streamHasAudio];
        [_overlayView setStreamHasVideo:_streamHasVideo];
        
        [_underlayView setHidden:YES];
        [_loadingView setHidden:YES];
        
        [self addSubview:_videoViewHolder];
        [self addSubview:_underlayView];
        [self addSubview:_loadingView];
        [self addSubview:_overlayView];

        
        UITapGestureRecognizer* tap =
        [[UITapGestureRecognizer alloc] initWithTarget:_overlayView
                                                action:@selector(showOverlay:)];
        [tap setNumberOfTapsRequired:1];
        [tap setCancelsTouchesInView:NO];
        [self addGestureRecognizer:tap];
        
        self.userInteractionEnabled = YES;
        self.clipsToBounds = YES;
        
        [self setStreamHasAudio:_streamHasAudio];
        [self setStreamHasVideo:_streamHasVideo];
        
        if (type == OTVideoViewTypeSubscriber)
        {
            _audioOnlyView = [[UIView alloc] initWithFrame:frame];
            _audioOnlyView.hidden = YES;
            
            UIImageView *headset = [[UIImageView alloc]
                                    initWithImage:[UIImage
                                                   imageNamed:@"Headset.png"]];
            headset.tag = HEADSET_VEW_TAG;
            
            UIImageView *silhouette = [[UIImageView alloc]
                                       initWithImage:[UIImage
                                                imageNamed:@"silhouette.png"]];
            silhouette.tag = SILHOUETTE_VEW_TAG;
            
            [_audioOnlyView addSubview:headset];
            [_audioOnlyView addSubview:silhouette];
            
            _audioLevelMeter = [[TBAudioLevelMeter alloc]
                                 initWithFrame:CGRectZero];
            _audioLevelMeter.opaque = false;
            _audioLevelMeter.userInteractionEnabled = NO;
            CGRect frame = CGRectMake([[UIScreen mainScreen] bounds].size.width -
                                      66,
                                      10 ,
                                      140,
                                      140);
            _audioLevelMeter.frame = frame;
            [self insertSubview:_audioOnlyView belowSubview:_overlayView];
            [_audioOnlyView addSubview:_audioLevelMeter];
            [_audioOnlyView bringSubviewToFront:headset];
            [headset release];
            [silhouette release];
        }

    }
    return self;
}

- (void)showAudioOnlyUnderlay:(BOOL)showUnderlay
{
    _underlayView.hidden = !showUnderlay;
}

- (void)setDisplayName:(NSString*)name {
    _overlayView.displayName = name;
}

- (void)setStreamHasAudio:(BOOL)streamHasAudio
{
    _streamHasAudio = streamHasAudio;
    [_underlayView setAudioActive:streamHasAudio];
    [_overlayView setStreamHasAudio:streamHasAudio];
 
    [self setNeedsLayout];
}

- (void)setStreamHasVideo:(BOOL)streamHasVideo
{
    _streamHasVideo = streamHasVideo;
    [_overlayView setStreamHasVideo:_streamHasVideo];
    [self showAudioOnlyUnderlay:!_streamHasVideo];
    
    [self setNeedsLayout];
}

- (void)showLoadingView:(BOOL)showLoadingView
{
    _loadingView.hidden = !showLoadingView;
}

- (void)layoutSubviews {
    
    [super layoutSubviews];

    if (_type == OTVideoViewTypeSubscriber) {
        if ([self videoAspectRatio] > 0) {

            _videoViewHolder.frame = CGRectMake(0, 0,
                                                self.frame.size.width,
                                                self.frame.size.height);
            _videoView.frame = _videoViewHolder.frame;
            _videoViewHolder.center = CGPointMake(self.frame.size.width/2,
                                                  self.frame.size.height/2);
            
        } else {
            NSLog(@"VideoView frame can't be set without known video "
                  "dimensions...");
        }

        _audioOnlyView.frame = CGRectMake(0,
                                          0,
                                          self.frame.size.width,
                                          self.frame.size.height);
        UIImageView *headsetImgView = (UIImageView *)[self.audioOnlyView
                                       viewWithTag:HEADSET_VEW_TAG];
        CGRect audioMeterFrame = self.audioLevelMeter.frame;
        CGRect frame = headsetImgView.frame;
        frame.size.width = 40;
        frame.size.height = 40;
        frame.origin.x = audioMeterFrame.origin.x  +
        audioMeterFrame.size.width/4 - frame.size.width/2;
        frame.origin.y =
        audioMeterFrame.size.height/4 - frame.size.height/2;
        headsetImgView.frame = frame;
        
        UIImageView *silhouetteImgView = (UIImageView *)[self.audioOnlyView
                                            viewWithTag:SILHOUETTE_VEW_TAG];
        frame = silhouetteImgView.frame;
        frame.size.width = 200;
        frame.size.height = 200;
        frame.origin.x = self.frame.size.width/2 -
        frame.size.width/2;
        frame.origin.y =
        self.frame.size.height/2 - frame.size.height/2;
        silhouetteImgView.frame = frame;

        UIColor *backgroundColor = [UIColor colorWithRed:40.0f/255.0f
                                              green:40.0f/255.0f
                                               blue:40/255.0f
                                              alpha:1.f];
        _audioOnlyView.backgroundColor = backgroundColor;
        
    } else {
        
        float currentAspect = 1.2222;
        float desiredAspect = 1.3333;
        
        //aspect fill our publisher view
        float width = self.frame.size.width * (desiredAspect/currentAspect);
        float height = self.frame.size.height * (desiredAspect/currentAspect);
        _videoView.frame = CGRectMake(0, 0, width, height);
        _videoViewHolder.frame = CGRectMake(0, 0, width, height);
        
        //center it so it clips and is properly letterboxed by the superview
        _videoViewHolder.center = CGPointMake(self.frame.size.width/2,
                                              self.frame.size.height/2);
        
    }
        
    [_underlayView setFrame:CGRectMake(0, 0,
                                       self.frame.size.width,
                                       self.frame.size.height)];
    [_loadingView setFrame:CGRectMake(0, 0,
                                      self.frame.size.width,
                                      self.frame.size.height)];
    [_overlayView setFrame:CGRectMake(0, 0,
                                      self.frame.size.width,
                                      self.frame.size.height)];
    
    [_activityIndicatorView setCenter:_loadingView.center];
    _activityIndicatorView.activityIndicatorViewStyle =
    (self.frame.size.height >= 120) ?
    UIActivityIndicatorViewStyleWhiteLarge : UIActivityIndicatorViewStyleWhite;
    
    [_lblLoading
     setCenter:CGPointMake(_loadingView.center.x,
                           _loadingView.center.y +
                           _activityIndicatorView.frame.size.height)];
    [_lblLoading
     setHidden:((self.frame.size.height < (_lblLoading.frame.size.width + 10))
                || (self.frame.size.height < 120))];
}

- (UIView*)toolbarView {
    return _overlayView.toolbarView;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];

    [self setNeedsLayout];
}

- (float)videoAspectRatio {
    if (CGSizeEqualToSize(_videoDimensions, CGSizeZero))
        return 1.3333; //default to 4:3 aspect ratio
    
    return _videoDimensions.width / _videoDimensions.height;
}

- (void)setVideoDimensions:(CGSize)dimensions {
    _videoDimensions = dimensions;
    
    [self setNeedsLayout];
}

- (void)setStream:(OTStream *)stream {
    _stream = stream;
}

-(void)dealloc
{
    [super dealloc];
    [_audioOnlyView release];
    [_audioLevelMeter release];
}

#pragma mark - OTOverlayViewDelegate -

- (void)overlayViewDidToggleCamera:(TBExampleOverlayView*)overlayView
{
    if ([_delegate respondsToSelector:@selector(videoViewDidToggleCamera:)]) {
        [_delegate videoViewDidToggleCamera:self];
    }
}

- (void)overlayView:(TBExampleOverlayView*)overlay
  publisherWasMuted:(BOOL)publisherMuted
{
    if ([_delegate respondsToSelector:@selector(videoView:publisherWasMuted:)])
    {
        [_delegate videoView:self publisherWasMuted:publisherMuted];
    }
}

- (void)     overlayView:(TBExampleOverlayView*)overlay
subscriberVolumeWasMuted:(BOOL)subscriberMuted
{
    if ([_delegate
         respondsToSelector:@selector(videoView:subscriberVolumeWasMuted:)])
    {
        [_delegate videoView:self subscriberVolumeWasMuted:subscriberMuted];
    }
}

#pragma mark - OTVideoRender -
- (void)renderVideoFrame:(OTVideoFrame*) frame {
    [_videoView renderVideoFrame:frame];
}

@end
