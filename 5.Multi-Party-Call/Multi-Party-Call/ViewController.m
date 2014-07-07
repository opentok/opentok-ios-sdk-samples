//
//  ViewController.m
//  Multi-Party-Call
//
//  Created by Sridhar on 07/04/14.
//  Copyright (c) 2014 Tokbox. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

#import "ViewController.h"
#import <OpenTok/OpenTok.h>

static NSString *const kApiKey = @"";
// Replace with your generated session ID
static NSString *const kSessionId = @"";
// Replace with your generated token
static NSString *const kToken = @"";

#define APP_IN_FULL_SCREEN @"appInFullScreenMode"
#define PUBLISHER_BAR_HEIGHT 50.0f
#define SUBSCRIBER_BAR_HEIGHT 66.0f
#define ARCHIVE_BAR_HEIGHT 35.0f
#define PUBLISHER_ARCHIVE_CONTAINER_HEIGHT 85.0f

#define PUBLISHER_PREVIEW_HEIGHT 87.0f
#define PUBLISHER_PREVIEW_WIDTH 113.0f

#define OVERLAY_HIDE_TIME 7.0f

// otherwise no upside down rotation
@interface UINavigationController (RotationAll)
- (NSUInteger)supportedInterfaceOrientations;
@end


@implementation UINavigationController (RotationAll)
- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

@end

@interface ViewController ()<OTSessionDelegate, OTSubscriberKitDelegate,
OTPublisherDelegate>{
	NSMutableDictionary *allStreams;
	NSMutableDictionary *allSubscribers;
	NSMutableArray *allConnectionsIds;
    
	OTSession *_session;
	OTPublisher *_publisher;
	OTSubscriber *_currentSubscriber;
	CGPoint _startPosition;
    
	BOOL initialized;
}

@end

@implementation ViewController

@synthesize videoContainerView;

- (void)viewDidLoad
{
	[super viewDidLoad];
    
    self.videoContainerView.bounces = NO;
    
	[self.view sendSubviewToBack:self.videoContainerView];
	self.endCallButton.titleLabel.lineBreakMode = NSLineBreakByCharWrapping;
	self.endCallButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    
	// Default no full screen
	[self.topOverlayView.layer setValue:[NSNumber numberWithBool:NO]
                                 forKey:APP_IN_FULL_SCREEN];
    
    
	self.audioPubUnpubButton.autoresizingMask  =
    UIViewAutoresizingFlexibleLeftMargin
    | UIViewAutoresizingFlexibleRightMargin |
    UIViewAutoresizingFlexibleTopMargin |
    UIViewAutoresizingFlexibleBottomMargin;
    
    
	// Add right side border to camera toggle button
	CALayer *rightBorder = [CALayer layer];
	rightBorder.borderColor = [UIColor whiteColor].CGColor;
	rightBorder.borderWidth = 1;
	rightBorder.frame =
    CGRectMake(-1,
               -1,
               CGRectGetWidth(self.cameraToggleButton.frame),
               CGRectGetHeight(self.cameraToggleButton.frame) + 2);
	self.cameraToggleButton.clipsToBounds = YES;
	[self.cameraToggleButton.layer addSublayer:rightBorder];
    
	// Left side border to audio publish/unpublish button
	CALayer *leftBorder = [CALayer layer];
	leftBorder.borderColor = [UIColor whiteColor].CGColor;
	leftBorder.borderWidth = 1;
	leftBorder.frame =
    CGRectMake(-1,
               -1,
               CGRectGetWidth(self.audioPubUnpubButton.frame) + 5,
               CGRectGetHeight(self.audioPubUnpubButton.frame) + 2);
	[self.audioPubUnpubButton.layer addSublayer:leftBorder];
    
    // configure video container view
	self.videoContainerView.scrollEnabled = YES;
	videoContainerView.pagingEnabled = YES;
	videoContainerView.delegate = self;
	videoContainerView.showsHorizontalScrollIndicator = NO;
	videoContainerView.showsVerticalScrollIndicator = YES;
	videoContainerView.bounces = NO;
	videoContainerView.alwaysBounceHorizontal = NO;
    
    
	// initialize constants
	allStreams = [[NSMutableDictionary alloc] init];
	allSubscribers = [[NSMutableDictionary alloc] init];
	allConnectionsIds = [[NSMutableArray alloc] init];
    
    
	// set up look of the page
	[self.navigationController setNavigationBarHidden:YES];
    [self setNeedsStatusBarAppearanceUpdate];
    
    
	// listen to taps around the screen, and hide/show overlay views
	UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(viewTapped:)];
	tgr.delegate = self;
	[self.view addGestureRecognizer:tgr];
	[tgr release];
    
    UITapGestureRecognizer *leftArrowTapGesture = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(handleArrowTap:)];
	leftArrowTapGesture.delegate = self;
	[self.leftArrowImgView addGestureRecognizer:leftArrowTapGesture];
	[leftArrowTapGesture release];

    UITapGestureRecognizer *rightArrowTapGesture = [[UITapGestureRecognizer alloc]
                                                   initWithTarget:self
                                                   action:@selector(handleArrowTap:)];
	rightArrowTapGesture.delegate = self;
	[self.rightArrowImgView addGestureRecognizer:rightArrowTapGesture];
	[rightArrowTapGesture release];

    [self resetArrowsStates];
    
    self.archiveOverlay.hidden = YES;
    
    [self setupSession];
    
    [self.endCallButton sendActionsForControlEvents:UIControlEventTouchUpInside];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

- (void)viewTapped:(UITapGestureRecognizer *)tgr
{
	BOOL isInFullScreen = [[[self topOverlayView].layer
                            valueForKey:APP_IN_FULL_SCREEN] boolValue];
    
	UIInterfaceOrientation orientation =
    [[UIApplication sharedApplication] statusBarOrientation];
    
	if (isInFullScreen) {
		
        [self.topOverlayView.layer setValue:[NSNumber numberWithBool:NO]
                                     forKey:APP_IN_FULL_SCREEN];
		
            // Show/Adjust top, bottom, archive, publisher and video container
            // views according to the orientation
            if (orientation == UIInterfaceOrientationPortrait ||
                orientation == UIInterfaceOrientationPortraitUpsideDown) {
                
                
                [UIView animateWithDuration:0.5 animations:^{

                    CGRect frame = _currentSubscriber.view.frame;
                    frame.size.height =
                    self.videoContainerView.frame.size.height;
                    _currentSubscriber.view.frame = frame;

                    frame = self.topOverlayView.frame;
                    frame.origin.y += frame.size.height;
                    self.topOverlayView.frame = frame;
                    
                    frame = self.archiveOverlay.superview.frame;
                    frame.origin.y -= frame.size.height;
                    self.archiveOverlay.superview.frame = frame;
                    
                    [_publisher.view setFrame:
                     CGRectMake(8,
                                self.view.frame.size.height -
                                (PUBLISHER_BAR_HEIGHT +
                                 (self.archiveOverlay.hidden ? 0 :
                                  ARCHIVE_BAR_HEIGHT)
                                 + 8 + PUBLISHER_PREVIEW_HEIGHT),
                                PUBLISHER_PREVIEW_WIDTH,
                                PUBLISHER_PREVIEW_HEIGHT)];
                } completion:^(BOOL finished) {

                }];
            }
            else
            {
                
                [UIView animateWithDuration:0.5 animations:^{
                    
                    CGRect frame = _currentSubscriber.view.frame;
                    frame.size.width =
                    self.videoContainerView.frame.size.width;
                    _currentSubscriber.view.frame = frame;

                    frame = self.topOverlayView.frame;
                    frame.origin.y += frame.size.height;
                    self.topOverlayView.frame = frame;
                    
                    frame = self.bottomOverlayView.frame;
                    if (orientation == UIInterfaceOrientationLandscapeRight) {
                        frame.origin.x -= frame.size.width;
                    } else {
                        frame.origin.x += frame.size.width;
                    }
                    
                    self.bottomOverlayView.frame = frame;
                    
                    frame = self.archiveOverlay.frame;
                    frame.origin.y -= frame.size.height;
                    self.archiveOverlay.frame = frame;
                    
                    if (orientation == UIInterfaceOrientationLandscapeRight) {
                        [_publisher.view setFrame:
                         CGRectMake(8,
                                    self.view.frame.size.height -
                                    ((self.archiveOverlay.hidden ? 0 :
                                      ARCHIVE_BAR_HEIGHT) + 8 +
                                     PUBLISHER_PREVIEW_HEIGHT),
                                    PUBLISHER_PREVIEW_WIDTH,
                                    PUBLISHER_PREVIEW_HEIGHT)];
                        
                        self.rightArrowImgView.frame =
                        CGRectMake(videoContainerView.frame.size.width - 40 -
                                   10 - PUBLISHER_BAR_HEIGHT,
                                   videoContainerView.frame.size.height/2 - 20,
                                   40,
                                   40);

                       
                    } else {
                        [_publisher.view setFrame:
                         CGRectMake(PUBLISHER_BAR_HEIGHT + 8,
                                    self.view.frame.size.height -
                                    ((self.archiveOverlay.hidden ? 0 :
                                      ARCHIVE_BAR_HEIGHT) + 8 +
                                     PUBLISHER_PREVIEW_HEIGHT),
                                    PUBLISHER_PREVIEW_WIDTH,
                                    PUBLISHER_PREVIEW_HEIGHT)];

                        self.leftArrowImgView.frame =
                        CGRectMake(10 + PUBLISHER_BAR_HEIGHT,
                                   videoContainerView.frame.size.height/2 - 20,
                                   40,
                                   40);

                    }
                } completion:^(BOOL finished) {

                    
                }];
            }
        
		// start overlay hide timer
		self.overlayTimer =
        [NSTimer scheduledTimerWithTimeInterval:OVERLAY_HIDE_TIME
                                         target:self
                                       selector:@selector(overlayTimerAction)
                                       userInfo:nil
                                        repeats:NO];
	}
	else
	{
		[self.topOverlayView.layer setValue:[NSNumber numberWithBool:YES]
                                     forKey:APP_IN_FULL_SCREEN];
        
		// invalidate timer so that it wont hide again
		[self.overlayTimer invalidate];
		
        
        // Hide/Adjust top, bottom, archive, publisher and video container
        // views according to the orientation
        if (orientation == UIInterfaceOrientationPortrait ||
            orientation == UIInterfaceOrientationPortraitUpsideDown)
        {
            
            [UIView animateWithDuration:0.5 animations:^{
                
                CGRect frame = _currentSubscriber.view.frame;
                // User really tapped (not from willAnimateToration...)
                if (tgr)
                {
                    frame.size.height =
                    self.videoContainerView.frame.size.height;
                    _currentSubscriber.view.frame = frame;
                }

                frame = self.topOverlayView.frame;
                frame.origin.y -= frame.size.height;
                self.topOverlayView.frame = frame;
                
                frame = self.archiveOverlay.superview.frame;
                frame.origin.y += frame.size.height;
                self.archiveOverlay.superview.frame = frame;
                
                
                [_publisher.view setFrame:
                 CGRectMake(8,
                            self.view.frame.size.height -
                            (8 + PUBLISHER_PREVIEW_HEIGHT),
                            PUBLISHER_PREVIEW_WIDTH,
                            PUBLISHER_PREVIEW_HEIGHT)];
            } completion:^(BOOL finished) {
            }];
            
        }
        else
        {
            
            [UIView animateWithDuration:0.5 animations:^{
                
                CGRect frame = _currentSubscriber.view.frame;
                frame.size.width =
                self.videoContainerView.frame.size.width;
                _currentSubscriber.view.frame = frame;

                frame = self.topOverlayView.frame;
                frame.origin.y -= frame.size.height;
                self.topOverlayView.frame = frame;
                
                frame = self.bottomOverlayView.frame;
                if (orientation == UIInterfaceOrientationLandscapeRight) {
                    frame.origin.x += frame.size.width;
                    
                    self.rightArrowImgView.frame =
                    CGRectMake(videoContainerView.frame.size.width - 40 - 10,
                               videoContainerView.frame.size.height/2 - 20,
                               40,
                               40);

                } else {
                    frame.origin.x -= frame.size.width;
                    
                    self.leftArrowImgView.frame =
                    CGRectMake(10 ,
                               videoContainerView.frame.size.height/2 - 20,
                               40,
                               40);

                }
                
                self.bottomOverlayView.frame = frame;
                
                frame = self.archiveOverlay.frame;
                frame.origin.y += frame.size.height;
                self.archiveOverlay.frame = frame;
                

                [_publisher.view setFrame:
                 CGRectMake(8,
                            self.view.frame.size.height -
                            (8 + PUBLISHER_PREVIEW_HEIGHT),
                            PUBLISHER_PREVIEW_WIDTH,
                            PUBLISHER_PREVIEW_HEIGHT)];
            } completion:^(BOOL finished) {
            }];
        }
	}
    
    // no need to arrange subscribers when it comes from willRotate
    if (tgr)
    {
        [self reArrangeSubscribers];
    }
        
}

- (void)overlayTimerAction
{
	BOOL isInFullScreen =   [[[self topOverlayView].layer
                              valueForKey:APP_IN_FULL_SCREEN] boolValue];
    
	// if any button is in highlighted state, we ignore hide action
	if (!self.cameraToggleButton.highlighted &&
		!self.audioPubUnpubButton.highlighted &&
		!self.audioPubUnpubButton.highlighted) {
		// Hide views
		if (!isInFullScreen) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self viewTapped:[[self.view gestureRecognizers]
                                  objectAtIndex:0]];
            });
			
            //[[[self.view gestureRecognizers] objectAtIndex:0] sendActionsForControlEvents:UIControlEventTouchUpInside];

		}
	} else {
		// start the timer again for next time
		self.overlayTimer =
        [NSTimer scheduledTimerWithTimeInterval:OVERLAY_HIDE_TIME
                                         target:self
                                       selector:@selector(overlayTimerAction)
                                       userInfo:nil
                                        repeats:NO];
	}
}

- (BOOL)shouldAutorotate
{
	return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:
(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:
     toInterfaceOrientation duration:duration];
    
	BOOL isInFullScreen =   [[[self topOverlayView].layer
                              valueForKey:APP_IN_FULL_SCREEN] boolValue];
    
    // hide overlay views adjust positions based on orietnation and then
    // hide them again
	if (isInFullScreen) {
		// hide all bars to before rotate
		self.topOverlayView.hidden = YES;
		self.bottomOverlayView.hidden = YES;
	}
    
	int connectionsCount = [allConnectionsIds count];
	UIInterfaceOrientation orientation = toInterfaceOrientation;
    
    // adjust overlay views
	if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {
		
        [videoContainerView setFrame:
		 CGRectMake(0,
                    0,
                    self.view.frame.size.width,
                    self.view.frame.size.height)];
        
		[_publisher.view setFrame:
		 CGRectMake(8,
                    self.view.frame.size.height -
                    (isInFullScreen ? PUBLISHER_PREVIEW_HEIGHT + 8 :
                     (PUBLISHER_BAR_HEIGHT +
                      (self.archiveOverlay.hidden ? 0 :
                      ARCHIVE_BAR_HEIGHT) + 8 +
                      PUBLISHER_PREVIEW_HEIGHT)),
                    PUBLISHER_PREVIEW_WIDTH,
                    PUBLISHER_PREVIEW_HEIGHT)];
        
        
        UIView *containerView = self.archiveOverlay.superview;
        containerView.frame =
        CGRectMake(0,
                   self.view.frame.size.height -
                   PUBLISHER_ARCHIVE_CONTAINER_HEIGHT,
                   self.view.frame.size.width,
                   PUBLISHER_ARCHIVE_CONTAINER_HEIGHT);
        
        [self.bottomOverlayView removeFromSuperview];
        [containerView addSubview:self.bottomOverlayView];
        
		self.bottomOverlayView.frame =
        CGRectMake(0,
                   containerView.frame.size.height - PUBLISHER_BAR_HEIGHT,
                   containerView.frame.size.width,
                   PUBLISHER_BAR_HEIGHT);
        
        // Archiving overlay
		self.archiveOverlay.frame =
        CGRectMake(0,
                   0,
                   self.view.frame.size.width,
                   ARCHIVE_BAR_HEIGHT);
        
		self.topOverlayView.frame =
        CGRectMake(0,
                   0,
                   self.view.frame.size.width,
                   self.topOverlayView.frame.size.height);
        
		// Camera button
		self.cameraToggleButton.frame =
        CGRectMake(0, 0, 90, PUBLISHER_BAR_HEIGHT);
        
        //adjust border layer
		CALayer *borderLayer = [[self.cameraToggleButton.layer sublayers]
                                objectAtIndex:1];
		borderLayer.frame =
        CGRectMake(-1,
                   -1,
                   CGRectGetWidth(self.cameraToggleButton.frame),
                   CGRectGetHeight(self.cameraToggleButton.frame) + 2);
        
		// adjust call button
		self.endCallButton.frame =
        CGRectMake((self.bottomOverlayView.frame.size.width / 2) - (140 / 2),
                   0,
                   140,
                   PUBLISHER_BAR_HEIGHT);
        
		// Mic button
		self.audioPubUnpubButton.frame =
        CGRectMake(self.bottomOverlayView.frame.size.width - 90,
                   0,
                   90,
                   PUBLISHER_BAR_HEIGHT);
        
		borderLayer = [[self.audioPubUnpubButton.layer sublayers]
                       objectAtIndex:1];
		borderLayer.frame =
        CGRectMake(-1,
                   -1,
                   CGRectGetWidth(self.audioPubUnpubButton.frame) + 5,
                   CGRectGetHeight(self.audioPubUnpubButton.frame) + 2);
        
        self.leftArrowImgView.frame =
        CGRectMake(10,
                   videoContainerView.frame.size.height/2 - 20,
                   40,
                   40);
        
        self.rightArrowImgView.frame =
        CGRectMake(videoContainerView.frame.size.width - 40 - 10,
                   videoContainerView.frame.size.height/2 - 20,
                   40,
                   40);

		[videoContainerView setContentSize:
         CGSizeMake(videoContainerView.frame.size.width * (connectionsCount ),
                    videoContainerView.frame.size.height)];
	}
	else if (orientation == UIInterfaceOrientationLandscapeLeft ||
             orientation == UIInterfaceOrientationLandscapeRight) {
		
        
		if (orientation == UIInterfaceOrientationLandscapeRight) {
			
            [videoContainerView setFrame:
			 CGRectMake(0,
                        0,
                        self.view.frame.size.width,
                        self.view.frame.size.height)];
            
			[_publisher.view setFrame:
			 CGRectMake(8,
                        self.view.frame.size.height -
                        ((self.archiveOverlay.hidden ? 0 : ARCHIVE_BAR_HEIGHT)
                         + 8 + PUBLISHER_PREVIEW_HEIGHT),
                        PUBLISHER_PREVIEW_WIDTH,
                        PUBLISHER_PREVIEW_HEIGHT)];
            
            UIView *containerView = self.archiveOverlay.superview;
            containerView.frame =
            CGRectMake(0,
                       self.view.frame.size.height - ARCHIVE_BAR_HEIGHT,
                       self.view.frame.size.width - PUBLISHER_BAR_HEIGHT,
                       ARCHIVE_BAR_HEIGHT);
            
            // Archiving overlay
			self.archiveOverlay.frame =
            CGRectMake(0,
                       containerView.frame.size.height - ARCHIVE_BAR_HEIGHT,
                       containerView.frame.size.width ,
                       ARCHIVE_BAR_HEIGHT);
            
            [self.bottomOverlayView removeFromSuperview];
            [self.view addSubview:self.bottomOverlayView];
            
            self.bottomOverlayView.frame =
            CGRectMake(self.view.frame.size.width - PUBLISHER_BAR_HEIGHT,
                       0,
                       PUBLISHER_BAR_HEIGHT,
                       self.view.frame.size.height);
            
			// Top overlay
			self.topOverlayView.frame =
            CGRectMake(0,
                       0,
                       self.view.frame.size.width - PUBLISHER_BAR_HEIGHT,
                       self.topOverlayView.frame.size.height);
            
            self.leftArrowImgView.frame =
            CGRectMake(10,
                       videoContainerView.frame.size.height/2 - 20,
                       40,
                       40);
            
            self.rightArrowImgView.frame =
            CGRectMake(self.view.frame.size.width - 40 - 10 -
                       PUBLISHER_BAR_HEIGHT,
                       videoContainerView.frame.size.height/2 - 20,
                       40,
                       40);

            
            
		}
		else
		{
			[videoContainerView setFrame:
			 CGRectMake(0,
                        0,
                        self.view.frame.size.width ,
                        self.view.frame.size.height)];
            
			[_publisher.view setFrame:
			 CGRectMake(8 + PUBLISHER_BAR_HEIGHT,
                        self.view.frame.size.height -
                        ((self.archiveOverlay.hidden ? 0 : ARCHIVE_BAR_HEIGHT)
                         + 8 + PUBLISHER_PREVIEW_HEIGHT),
                        PUBLISHER_PREVIEW_WIDTH,
                        PUBLISHER_PREVIEW_HEIGHT)];
            
            
            UIView *containerView = self.archiveOverlay.superview;
            containerView.frame =
            CGRectMake(PUBLISHER_BAR_HEIGHT,
                       self.view.frame.size.height - ARCHIVE_BAR_HEIGHT,
                       self.view.frame.size.width - PUBLISHER_BAR_HEIGHT,
                       ARCHIVE_BAR_HEIGHT);
            
            [self.bottomOverlayView removeFromSuperview];
            [self.view addSubview:self.bottomOverlayView];
            
			self.bottomOverlayView.frame =
            CGRectMake(0,
                       0,
                       PUBLISHER_BAR_HEIGHT,
                       self.view.frame.size.height);
            
            // Archiving overlay
			self.archiveOverlay.frame =
            CGRectMake(0,
                       containerView.frame.size.height - ARCHIVE_BAR_HEIGHT,
                       containerView.frame.size.width ,
                       ARCHIVE_BAR_HEIGHT);
            
			self.topOverlayView.frame =
            CGRectMake(PUBLISHER_BAR_HEIGHT,
                       0,
                       self.view.frame.size.width - PUBLISHER_BAR_HEIGHT,
                       self.topOverlayView.frame.size.height);
            
            self.leftArrowImgView.frame =
            CGRectMake(10 + PUBLISHER_BAR_HEIGHT,
                       videoContainerView.frame.size.height/2 - 20,
                       40,
                       40);
            
            self.rightArrowImgView.frame =
            CGRectMake(self.view.frame.size.width - 40 - 10 ,
                       videoContainerView.frame.size.height/2 - 20,
                       40,
                       40);
            
		}
        
		// Mic button
		CGRect frame =  self.audioPubUnpubButton.frame;
		frame.origin.x = 0;
		frame.origin.y = 0;
		frame.size.width = PUBLISHER_BAR_HEIGHT;
		frame.size.height = 90;
        
		self.audioPubUnpubButton.frame = frame;
        
        // vertical border
		frame.origin.x = -1;
		frame.origin.y = -1;
		frame.size.width = 55;
		CALayer *borderLayer = [[self.audioPubUnpubButton.layer sublayers]
                                objectAtIndex:1];
		borderLayer.frame = frame;
        
		// Camera button
		frame =  self.cameraToggleButton.frame;
		frame.origin.x = 0;
		frame.origin.y = self.bottomOverlayView.frame.size.height - 100;
		frame.size.width = PUBLISHER_BAR_HEIGHT;
		frame.size.height = 90;
        
		self.cameraToggleButton.frame = frame;
        
		frame.origin.x = -1;
		frame.origin.y = 0;
		frame.size.height = 90;
		frame.size.width = 55;
        
		borderLayer = [[self.cameraToggleButton.layer sublayers]
                       objectAtIndex:1];
		borderLayer.frame =
        CGRectMake(0,
                   1,
                   CGRectGetWidth(self.cameraToggleButton.frame) ,
                   1
                   );
        
		// call button
		frame =  self.endCallButton.frame;
		frame.origin.x = 0;
		frame.origin.y = (self.bottomOverlayView.frame.size.height / 2) -
        (100 / 2);
		frame.size.width = PUBLISHER_BAR_HEIGHT;
		frame.size.height = 100;
        
		self.endCallButton.frame = frame;
        
		[videoContainerView setContentSize:
         CGSizeMake(videoContainerView.frame.size.width * connectionsCount,
                    videoContainerView.frame.size.height)];
	}
    
	if (isInFullScreen) {
        
        // call viewTapped to hide the views out of the screen.
		[[self topOverlayView].layer setValue:[NSNumber numberWithBool:NO]
                                       forKey:APP_IN_FULL_SCREEN];
		[self viewTapped:nil];
		[[self topOverlayView].layer setValue:[NSNumber numberWithBool:YES]
                                       forKey:APP_IN_FULL_SCREEN];
        
		self.topOverlayView.hidden = NO;
		self.bottomOverlayView.hidden = NO;
	}
	
    // re arrange subscribers
	[self reArrangeSubscribers];
    
    // set video container offset to current subscriber
	[videoContainerView setContentOffset:
     CGPointMake(_currentSubscriber.view.tag *
                 videoContainerView.frame.size.width, 0)
                                animated:YES];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    
    // current subscriber
	int currentPage = (int)(videoContainerView.contentOffset.x /
                            videoContainerView.frame.size.width);
    
	if (currentPage < [allConnectionsIds count]) {
        // show current scrolled subscriber
		NSString *connectionId = [allConnectionsIds objectAtIndex:currentPage];
        NSLog(@"show as current subscriber %@",connectionId);
		[self showAsCurrentSubscriber:[allSubscribers
                                       objectForKey:connectionId]];
	}
    [self resetArrowsStates];
}

- (void)showAsCurrentSubscriber:(OTSubscriber *)subscriber
{
    // scroll view tapping bug
    if(subscriber == _currentSubscriber)
        return;
    
	// unsubscribe currently running video
	_currentSubscriber.subscribeToVideo = NO;
	
    // update as current subscriber
    _currentSubscriber = subscriber;
	self.userNameLabel.text = _currentSubscriber.stream.name;
    
	// subscribe to new subscriber
	_currentSubscriber.subscribeToVideo = YES;
    
    self.audioSubUnsubButton.selected = !_currentSubscriber.subscribeToAudio;
}

- (void)setupSession
{
    //setup one time session
	if (_session) {
		[_session release];
		_session = nil;
	}
    
	_session = [[OTSession alloc] initWithApiKey:kApiKey
									   sessionId:kSessionId
										delegate:self];
    [_session connectWithToken:kToken error:nil];
    [self setupPublisher];
    
}

- (void)setupPublisher
{
	// create one time publisher and style publisher
	_publisher = [[OTPublisher alloc]
                  initWithDelegate:self
                  name:[[UIDevice currentDevice] name]];
    
    [self willAnimateRotationToInterfaceOrientation:
     [[UIApplication sharedApplication] statusBarOrientation] duration:1.0];
    
	[self.view addSubview:_publisher.view];
    
	// add pan gesture to publisher
	UIPanGestureRecognizer *pgr = [[UIPanGestureRecognizer alloc]
								   initWithTarget:self
                                   action:@selector(handlePan:)];
	[_publisher.view addGestureRecognizer:pgr];
	pgr.delegate = self;
	_publisher.view.userInteractionEnabled = YES;
	[pgr release];
}

- (IBAction)handlePan:(UIPanGestureRecognizer *)recognizer
{

    CGPoint translation = [recognizer translationInView:_publisher.view];
    CGRect recognizerFrame = recognizer.view.frame;
    recognizerFrame.origin.x += translation.x;
    recognizerFrame.origin.y += translation.y;
    

    if (CGRectContainsRect(self.view.bounds, recognizerFrame)) {
        recognizer.view.frame = recognizerFrame;
    }
    else {
        if (recognizerFrame.origin.y < self.view.bounds.origin.y) {
            recognizerFrame.origin.y = 0;
        }
        else if (recognizerFrame.origin.y + recognizerFrame.size.height > self.view.bounds.size.height) {
            recognizerFrame.origin.y = self.view.bounds.size.height - recognizerFrame.size.height;
        }
        
        if (recognizerFrame.origin.x < self.view.bounds.origin.x) {
            recognizerFrame.origin.x = 0;
        }
        else if (recognizerFrame.origin.x + recognizerFrame.size.width > self.view.bounds.size.width) {
            recognizerFrame.origin.x = self.view.bounds.size.width - recognizerFrame.size.width;
        }
    }
        [recognizer setTranslation:CGPointMake(0, 0) inView:_publisher.view];
}

- (void)handleArrowTap:(UIPanGestureRecognizer *)recognizer
{
    // if there are no subscribers, simply return
    if ([allSubscribers count] == 0)
        return;
    CGPoint touchPoint = [recognizer locationInView:self.leftArrowImgView];
    if ([self.leftArrowImgView pointInside:touchPoint withEvent:nil])
    {

        int currentPage = (int)(videoContainerView.contentOffset.x /
                                videoContainerView.frame.size.width) ;
        
        OTSubscriber *nextSubscriber = [allSubscribers objectForKey:
                              [allConnectionsIds objectAtIndex:currentPage - 1]];
        
        [self showAsCurrentSubscriber:nextSubscriber];
        
        [videoContainerView setContentOffset:
         CGPointMake(_currentSubscriber.view.frame.origin.x, 0) animated:YES];
        

    } else {
        
        int currentPage = (int)(videoContainerView.contentOffset.x /
                                videoContainerView.frame.size.width) ;
        
        OTSubscriber *nextSubscriber = [allSubscribers objectForKey:
                                               [allConnectionsIds objectAtIndex:currentPage + 1]];
        
        [self showAsCurrentSubscriber:nextSubscriber];
        
        [videoContainerView setContentOffset:
         CGPointMake(_currentSubscriber.view.frame.origin.x, 0) animated:YES];

    }
    
    [self resetArrowsStates];
}

- (void)resetArrowsStates
{
    
    if (!_currentSubscriber)
    {
        self.leftArrowImgView.image =
        [UIImage imageNamed:@"icon_arrowLeft_disabled-28.png"];
        self.leftArrowImgView.userInteractionEnabled = NO;
        
        self.rightArrowImgView.image =
        [UIImage imageNamed:@"icon_arrowRight_disabled-28.png"];
        self.rightArrowImgView.userInteractionEnabled = NO;
        return;
    }
    
    if (_currentSubscriber.view.tag == 0)
    {
        self.leftArrowImgView.image =
        [UIImage imageNamed:@"icon_arrowLeft_disabled-28.png"];
        self.leftArrowImgView.userInteractionEnabled = NO;
    } else
    {
        self.leftArrowImgView.image =
        [UIImage imageNamed:@"icon_arrowLeft_enabled-28.png"];
        self.leftArrowImgView.userInteractionEnabled = YES;
    }

    if (_currentSubscriber.view.tag == [allConnectionsIds count] - 1)
    {
        self.rightArrowImgView.image =
        [UIImage imageNamed:@"icon_arrowRight_disabled-28.png"];
        self.rightArrowImgView.userInteractionEnabled = NO;
    } else
    {
        self.rightArrowImgView.image =
        [UIImage imageNamed:@"icon_arrowRight_enabled-28.png"];
        self.rightArrowImgView.userInteractionEnabled = YES;
    }
}
#pragma mark - OpenTok Session
- (void)session:(OTSession *)session
	connectionDestroyed:(OTConnection *)connection
{
	NSLog(@"connectionDestroyed: %@", connection);
}

- (void)session:(OTSession *)session
	connectionCreated:(OTConnection *)connection
{
	NSLog(@"addConnection: %@", connection);
}

- (void)sessionDidConnect:(OTSession *)session
{
    // now publish
	OTError *error;
	[_session publish:_publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
}

- (void)reArrangeSubscribers
{
    
	CGFloat containerWidth = CGRectGetWidth(videoContainerView.bounds);
	CGFloat containerHeight = CGRectGetHeight(videoContainerView.bounds);
	int count = [allConnectionsIds count];
    
    // arrange all subscribers horizontally one by one.
	for (int i = 0; i < [allConnectionsIds count]; i++)
	{
		OTSubscriber *subscriber = [allSubscribers
                                           valueForKey:[allConnectionsIds
                                                        objectAtIndex:i]];
        subscriber.view.tag = i;
		[subscriber.view setFrame:
		 CGRectMake(i * CGRectGetWidth(videoContainerView.bounds),
                    0,
                    containerWidth,
                    containerHeight)];
        [videoContainerView addSubview:subscriber.view];
	}
    
	[videoContainerView setContentSize:
     CGSizeMake(videoContainerView.frame.size.width * (count ),
                videoContainerView.frame.size.height )];
	[videoContainerView setContentOffset:
       CGPointMake(_currentSubscriber.view.frame.origin.x, 0) animated:YES];
}

- (void)sessionDidDisconnect:(OTSession *)session
{
    
    // remove all subscriber views from video container
	for (int i = 0; i < [allConnectionsIds count]; i++)
	{
		OTSubscriber *subscriber = [allSubscribers valueForKey:
                                           [allConnectionsIds objectAtIndex:i]];
		[subscriber.view removeFromSuperview];
	}
    
	[_publisher.view removeFromSuperview];
    
	[allSubscribers removeAllObjects];
	[allConnectionsIds removeAllObjects];
	[allStreams removeAllObjects];
    
	_currentSubscriber = NULL;
	[_publisher release];
	_publisher = nil;
    
    if (self.archiveStatusImgView.isAnimating)
    {
        [self stopArchiveAnimation];
    }
    [self resetArrowsStates];
}

- (void)    session:(OTSession *)session
	streamDestroyed:(OTStream *)stream
{
	NSLog(@"streamDestroyed %@", stream.connection.connectionId);
	
    // get subscriber for this stream
	OTSubscriber *subscriber = [allSubscribers objectForKey:
                                       stream.connection.connectionId];
    
	// remove from superview
	[subscriber.view removeFromSuperview];
    
	[allSubscribers removeObjectForKey:stream.connection.connectionId];
	[allConnectionsIds removeObject:stream.connection.connectionId];
    
	_currentSubscriber = nil;
	[self reArrangeSubscribers];
	
    // show first subscriber
    if ([allConnectionsIds count] > 0) {
		NSString *firstConnection = [allConnectionsIds objectAtIndex:0];
		[self showAsCurrentSubscriber:[allSubscribers
                                       objectForKey:firstConnection]];
	}
    
    [self resetArrowsStates];
}

- (void)createSubscriber:(OTStream *)stream
{
	
    // create subscriber
	OTSubscriber *subscriber = [[OTSubscriber alloc]
                                       initWithStream:stream delegate:self];
    
	[allSubscribers setObject:subscriber forKey:stream.connection.connectionId];
	[allConnectionsIds addObject:stream.connection.connectionId];
    
    // set subscriber position and size
	CGFloat containerWidth = CGRectGetWidth(videoContainerView.bounds);
	CGFloat containerHeight = CGRectGetHeight(videoContainerView.bounds);
	int count = [allConnectionsIds count] - 1;
	[subscriber.view setFrame:
     CGRectMake(count *
                CGRectGetWidth(videoContainerView.bounds),
                0,
                containerWidth,
                containerHeight)];
    
	subscriber.view.tag = count;
    
    // add to video container view
	[videoContainerView insertSubview:subscriber.view
                         belowSubview:_publisher.view];
    
    // subscribe now
    OTError *error = nil;
	[_session subscribe:subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
    
	// default subscribe video to the first subscriber only
	if (!_currentSubscriber) {
		[self showAsCurrentSubscriber:subscriber];
	} else {
		subscriber.subscribeToVideo = NO;
	}
    
	// set scrollview content width based on number of subscribers connected.
	[videoContainerView setContentSize:
     CGSizeMake(videoContainerView.frame.size.width * (count + 1),
                videoContainerView.frame.size.height)];
    
	[allStreams setObject:stream forKey:stream.connection.connectionId];
    
	[subscriber release];
    [self resetArrowsStates];
}

- (void)publisher:(OTPublisherKit *)publisher
	streamCreated:(OTStream *)stream
{
    // create self subscriber
	[self createSubscriber:stream];
}

- (void)subscriberDidConnectToStream:(OTSubscriberKit *)subscriber
{
	NSLog(@"subscriberDidConnectToStream %@", subscriber.stream.name);
}

- (void)  session:(OTSession *)mySession
	streamCreated:(OTStream *)stream
{
    // create remote subscriber
	[self createSubscriber:stream];
}

- (void)session:(OTSession *)session didFailWithError:(OTError *)error
{
	NSLog(@"sessionDidFail");
	[self showAlert:
     [NSString stringWithFormat:@"There was an error connecting to session %@",
      session.sessionId]];
	[self endCallAction:nil];
}

- (void)publisher:(OTPublisher *)publisher didFailWithError:(OTError *)error
{
	NSLog(@"publisher didFailWithError %@", error);
	[self showAlert:[NSString stringWithFormat:
                     @"There was an error publishing."]];
	[self endCallAction:nil];
}

- (void)subscriber:(OTSubscriber *)subscriber didFailWithError:(OTError *)error
{
	NSLog(@"subscriber could not connect to stream");
}

#pragma mark - Helper Methods
- (IBAction)endCallAction:(UIButton *)button
{
	if (_session && _session.sessionConnectionStatus ==
        OTSessionConnectionStatusConnected) {
        // disconnect session
		NSLog(@"disconnecting....");
		[_session disconnect:nil];
		return;
	}
}

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[[UIAlertView alloc]
                               initWithTitle:@"Message from video session"
                               message:string
                               delegate:self
                               cancelButtonTitle:@"OK"
                               otherButtonTitles:nil] autorelease];
        [alert show];
    });
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Other Interactions
- (IBAction)toggleAudioSubscribe:(id)sender
{
	if (_currentSubscriber.subscribeToAudio == YES) {
		_currentSubscriber.subscribeToAudio = NO;
		self.audioSubUnsubButton.selected = YES;
	} else {
		_currentSubscriber.subscribeToAudio = YES;
		self.audioSubUnsubButton.selected = NO;
	}
}

- (void)dealloc
{
	[_cameraToggleButton release];
	[_audioPubUnpubButton release];
	[_userNameLabel release];
	[_audioSubUnsubButton release];
	[_overlayTimer release];
    
	[_endCallButton release];
	[_cameraSeparator release];
	[_micSeparator release];
	[_archiveOverlay release];
	[_archiveStatusLbl release];
	[_archiveStatusImgView release];
    [_leftArrowImgView release];
    [_rightArrowImgView release];
    [_rightArrowImgView release];
    [_leftArrowImgView release];
	[super dealloc];
}

- (IBAction)toggleCameraPosition:(id)sender
{
	if (_publisher.cameraPosition == AVCaptureDevicePositionBack) {
		_publisher.cameraPosition = AVCaptureDevicePositionFront;
		self.cameraToggleButton.selected = NO;
		self.cameraToggleButton.highlighted = NO;
	} else if (_publisher.cameraPosition == AVCaptureDevicePositionFront) {
		_publisher.cameraPosition = AVCaptureDevicePositionBack;
		self.cameraToggleButton.selected = YES;
		self.cameraToggleButton.highlighted = YES;
	}
}

- (IBAction)toggleAudioPublish:(id)sender
{
	if (_publisher.publishAudio == YES) {
		_publisher.publishAudio = NO;
		self.audioPubUnpubButton.selected = YES;
	} else {
		_publisher.publishAudio = YES;
		self.audioPubUnpubButton.selected = NO;
	}
}

- (void)startArchiveAnimation
{
    
    if (self.archiveOverlay.hidden)
    {
        self.archiveOverlay.hidden = NO;
        CGRect frame = _publisher.view.frame;
        frame.origin.y -= ARCHIVE_BAR_HEIGHT;
        _publisher.view.frame = frame;
    }
    BOOL isInFullScreen = [[[self topOverlayView].layer
                            valueForKey:APP_IN_FULL_SCREEN] boolValue];
    
    //show UI if it is in full screen
    if (isInFullScreen)
    {
        [self viewTapped:[self.view.gestureRecognizers objectAtIndex:0]];
    }
    

    // set animation images
    self.archiveStatusLbl.text = @"Archiving call";
    UIImage *imageOne = [UIImage imageNamed:@"archiving_on-5.png"];
    UIImage *imageTwo = [UIImage imageNamed:@"archiving_pulse-15.png"];
    NSArray *imagesArray =
    [NSArray arrayWithObjects:imageOne, imageTwo, nil];
    self.archiveStatusImgView.animationImages = imagesArray;
    self.archiveStatusImgView.animationDuration = 1.0f;
    self.archiveStatusImgView.animationRepeatCount = 0;
    [self.archiveStatusImgView startAnimating];
    
}

- (void)stopArchiveAnimation
{
    [self.archiveStatusImgView stopAnimating];
    self.archiveStatusLbl.text = @"Archiving off";
    self.archiveStatusImgView.image =
    [UIImage imageNamed:@"archiving_off-Small.png"];
    self.archiveOverlay.hidden = YES;
    BOOL isInFullScreen = [[[self topOverlayView].layer
                            valueForKey:APP_IN_FULL_SCREEN] boolValue];
    if (!isInFullScreen)
    {
        [_publisher.view setFrame:
         CGRectMake(8,
                    self.view.frame.size.height -
                    (PUBLISHER_BAR_HEIGHT +
                     (self.archiveOverlay.hidden ? 0 :
                      ARCHIVE_BAR_HEIGHT)
                     + 8 + PUBLISHER_PREVIEW_HEIGHT),
                    PUBLISHER_PREVIEW_WIDTH,
                    PUBLISHER_PREVIEW_HEIGHT)];
    }
}

- (void)session:(OTSession *)session
archiveStartedWithId:(NSString *)archiveId
           name:(NSString *)name
{
    NSLog(@"session archiving started");
    [self startArchiveAnimation];
}

- (void)session:(OTSession*)session
archiveStoppedWithId:(NSString *)archiveId
{
    NSLog(@"session archiving stopped");
    [self stopArchiveAnimation];
}

@end