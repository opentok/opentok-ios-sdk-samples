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
#import "TBExamplePublisher.h"
#import "TBExampleSubscriber.h"

static NSString *const kApiKey = @"";
// Replace with your generated session ID
static NSString *const kSessionId = @"";
// Replace with your generated token
static NSString *const kToken = @"";

#define APP_IN_FULL_SCREEN @"appInFullScreenMode"
#define PUBLISHER_BAR_HEIGHT 50.0f
#define SUBSCRIBER_BAR_HEIGHT 60.0f
#define ARCHIVE_BAR_HEIGHT 40.0f

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

@interface ViewController ()<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate>{
	NSMutableDictionary *allStreams;
	NSMutableDictionary *allSubscribers;
	NSMutableArray *allConnectionsIds;
    
	OTSession *_session;
	TBExamplePublisher *_publisher;
	TBExampleSubscriber *_currentSubscriber;
	CGPoint _startPosition;
    
	BOOL initialized;
}

@end
#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

@implementation ViewController

@synthesize videoContainerView;

- (void)viewDidLoad
{
	[super viewDidLoad];
    
	[self.view sendSubviewToBack:self.videoContainerView];
	self.callButton.titleLabel.lineBreakMode = NSLineBreakByCharWrapping;
	self.callButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    
	// Default no full screen
	[self.topOverlayView.layer setValue:[NSNumber numberWithBool:NO] forKey:APP_IN_FULL_SCREEN];
    
    
	self.audioPubUnpubButton.autoresizingMask  =  UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    
	// Add right side border to camera toggle button
	CALayer *rightBorder = [CALayer layer];
	rightBorder.borderColor = [UIColor whiteColor].CGColor;
	rightBorder.borderWidth = 1;
	rightBorder.frame = CGRectMake(-1, -1, CGRectGetWidth(self.cameraToggleButton.frame), CGRectGetHeight(self.cameraToggleButton.frame) + 2);
	self.cameraToggleButton.clipsToBounds = YES;
	[self.cameraToggleButton.layer addSublayer:rightBorder];
    
	// Left side border to audio publish/unpublish button
	CALayer *leftBorder = [CALayer layer];
	leftBorder.borderColor = [UIColor whiteColor].CGColor;
	leftBorder.borderWidth = 1;
	leftBorder.frame = CGRectMake(-1, -1, CGRectGetWidth(self.audioPubUnpubButton.frame) + 5, CGRectGetHeight(self.audioPubUnpubButton.frame) + 2);
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
	if (!SYSTEM_VERSION_LESS_THAN(@"7.0")) {
		[self setNeedsStatusBarAppearanceUpdate];
	}
    
	// listen to taps around the screen, and hide/show overlay views
	UITapGestureRecognizer *tgr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)];
	tgr.delegate = self;
	[self.view addGestureRecognizer:tgr];
	[tgr release];
    
    [self setupSession];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleLightContent;
}

- (void)viewTapped:(UITapGestureRecognizer *)tgr
{
	BOOL isInFullScreen = [[[self topOverlayView].layer valueForKey:APP_IN_FULL_SCREEN] boolValue];
    
	UIInterfaceOrientation orientation =
    [[UIApplication sharedApplication] statusBarOrientation];
    
	if (isInFullScreen) {
		
        [self.topOverlayView.layer setValue:[NSNumber numberWithBool:NO] forKey:APP_IN_FULL_SCREEN];
		
        [UIView animateWithDuration:0.5 animations:^{
            // Show/Adjust top, bottom, archive, publisher and video container views according to the orientation
            if (orientation == UIInterfaceOrientationPortrait ||
                orientation == UIInterfaceOrientationPortraitUpsideDown) {
                CGRect frame = self.topOverlayView.frame;
                frame.origin.y += frame.size.height;
                self.topOverlayView.frame = frame;
                
                frame = self.bottomOverlayView.frame;
                frame.origin.y -= frame.size.height;
                self.bottomOverlayView.frame = frame;
                
                frame = self.archiveOverlay.frame;
                frame.origin.y -=
                frame.size.height + self.bottomOverlayView.frame.size.height;
                self.archiveOverlay.frame = frame;
                
                frame = self.videoContainerView.frame;
                frame.size.height -=
                self.bottomOverlayView.frame.size.height;
                self.videoContainerView.frame = frame;
                
                [_publisher.view setFrame:
                 CGRectMake(10, self.view.frame.size.height -
                            (PUBLISHER_BAR_HEIGHT + ARCHIVE_BAR_HEIGHT + 10 + 110), 144, 110)];
            }
            else
            {
                
                CGRect frame = self.topOverlayView.frame;
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
                
                frame = self.videoContainerView.frame;
                if (orientation == UIInterfaceOrientationLandscapeLeft) {
                    frame.origin.x += self.bottomOverlayView.frame.size.width;
                }
                frame.size.width -=
                self.bottomOverlayView.frame.size.width;
                self.videoContainerView.frame = frame;
                
                if (orientation == UIInterfaceOrientationLandscapeRight) {
                    [_publisher.view setFrame:
                     CGRectMake(10, self.view.frame.size.height - (ARCHIVE_BAR_HEIGHT + 10 + 110), 144, 110)];
                } else {
                    [_publisher.view setFrame:
                     CGRectMake(PUBLISHER_BAR_HEIGHT + 10, self.view.frame.size.height -
                                (ARCHIVE_BAR_HEIGHT + 10 + 110), 144, 110)];
                }
            }
        } completion:^(BOOL finished) {
        }];
        
		// start overlay hide timer
		self.overlayTimer = [NSTimer scheduledTimerWithTimeInterval:OVERLAY_HIDE_TIME
															 target:self
														   selector:@selector(overlayTimerAction)
														   userInfo:nil
															repeats:NO];
	}
	else
	{
		[self.topOverlayView.layer setValue:[NSNumber numberWithBool:YES] forKey:APP_IN_FULL_SCREEN];
        
		// invalidate timer so that it wont hide again
		[self.overlayTimer invalidate];
		
        [UIView animateWithDuration:0.5 animations:^{
            // Hide/Adjust top, bottom, archive, publisher and video container views according to the orientation
            if (orientation == UIInterfaceOrientationPortrait ||
                orientation == UIInterfaceOrientationPortraitUpsideDown)
            {
                CGRect frame = self.topOverlayView.frame;
                frame.origin.y -= frame.size.height;
                self.topOverlayView.frame = frame;
                
                frame = self.bottomOverlayView.frame;
                frame.origin.y += frame.size.height;
                self.bottomOverlayView.frame = frame;
                
                frame = self.archiveOverlay.frame;
                frame.origin.y += frame.size.height + self.bottomOverlayView.frame.size.height;
                self.archiveOverlay.frame = frame;
                
                frame = self.videoContainerView.frame;
                frame.size.height +=
                self.bottomOverlayView.frame.size.height;
                self.videoContainerView.frame = frame;
                
                [_publisher.view setFrame:
                 CGRectMake(10, self.view.frame.size.height - (10 + 110), 144, 110)];
            }
            else
            {
                CGRect frame = self.topOverlayView.frame;
                frame.origin.y -= frame.size.height;
                self.topOverlayView.frame = frame;
                
                frame = self.bottomOverlayView.frame;
                if (orientation == UIInterfaceOrientationLandscapeRight) {
                    frame.origin.x += frame.size.width;
                } else {
                    frame.origin.x -= frame.size.width;
                }
                
                self.bottomOverlayView.frame = frame;
                
                frame = self.archiveOverlay.frame;
                frame.origin.y += frame.size.height;
                self.archiveOverlay.frame = frame;
                
                frame = self.videoContainerView.frame;
                if (orientation == UIInterfaceOrientationLandscapeLeft) {
                    frame.origin.x -= self.bottomOverlayView.frame.size.width;
                }
                frame.size.width +=
                self.bottomOverlayView.frame.size.width;
                self.videoContainerView.frame = frame;
                
                [_publisher.view setFrame:
                 CGRectMake(10, self.view.frame.size.height - (10 + 110), 144, 110)];
            }
        } completion:^(BOOL finished) {
        }];
	}
    
	// Re-arrange subscribers based on current orientation
	[self reArrangeSubscribers];
    
	// set the video container offset to the current subscriber
	[videoContainerView setContentOffset:CGPointMake(_currentSubscriber.view.tag * videoContainerView.frame.size.width, 0) animated:YES];
}

- (void)overlayTimerAction
{
	BOOL isInFullScreen =   [[[self topOverlayView].layer valueForKey:APP_IN_FULL_SCREEN] boolValue];
    
	// if any button is in highlighted state, we ignore hide action
	if (!self.cameraToggleButton.highlighted &&
		!self.audioPubUnpubButton.highlighted &&
		!self.audioPubUnpubButton.highlighted) {
		// Hide views
		if (!isInFullScreen) {
			[self viewTapped:nil];
		}
	} else {
		// start the timer again for next time
		self.overlayTimer = [NSTimer scheduledTimerWithTimeInterval:OVERLAY_HIDE_TIME
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

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    
	BOOL isInFullScreen =   [[[self topOverlayView].layer valueForKey:APP_IN_FULL_SCREEN] boolValue];
    
    //hide overlay views adjust positions based on orietnation and then hide them again
	if (isInFullScreen) {
		// hide all bars to before rotate
		self.topOverlayView.hidden = YES;
		self.bottomOverlayView.hidden = YES;
		self.archiveOverlay.hidden = YES;
	}
    
	int connectionsCount = [allConnectionsIds count];
	UIInterfaceOrientation orientation = toInterfaceOrientation;
    
    //adjust overlay views
	if (orientation == UIInterfaceOrientationPortrait ||
        orientation == UIInterfaceOrientationPortraitUpsideDown) {
		
        [videoContainerView setFrame:
		 CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height -
                    (isInFullScreen ? 0 : PUBLISHER_BAR_HEIGHT))];
        
		[_publisher.view setFrame:
		 CGRectMake(10, self.view.frame.size.height -
                    (isInFullScreen ? 110 + 10 :
                     (PUBLISHER_BAR_HEIGHT + ARCHIVE_BAR_HEIGHT + 10 + 110)),
                    144, 110)];
        
        
		self.bottomOverlayView.frame =
        CGRectMake(0, self.view.frame.size.height - PUBLISHER_BAR_HEIGHT,
                   self.view.frame.size.width, PUBLISHER_BAR_HEIGHT);
        
		self.topOverlayView.frame =
        CGRectMake(0, 0, self.view.frame.size.width, self.topOverlayView.frame.size.height);
        
		// Camera button
		self.cameraToggleButton.frame =
        CGRectMake(0, 0, 100, PUBLISHER_BAR_HEIGHT);
        
        //adjust border layer
		CALayer *borderLayer = [[self.cameraToggleButton.layer sublayers] objectAtIndex:1];
		borderLayer.frame = CGRectMake(-1, -1,
                                       CGRectGetWidth(self.cameraToggleButton.frame),
                                       CGRectGetHeight(self.cameraToggleButton.frame) + 2);
        
		// adjust call button
		self.callButton.frame =
        CGRectMake( (self.bottomOverlayView.frame.size.width / 2) - (100 / 2), 0, 100, PUBLISHER_BAR_HEIGHT);
        
		// Mic button
		self.audioPubUnpubButton.frame =
        CGRectMake(self.bottomOverlayView.frame.size.width - 100, 0, 100, PUBLISHER_BAR_HEIGHT);
        
		borderLayer = [[self.audioPubUnpubButton.layer sublayers] objectAtIndex:1];
		borderLayer.frame = CGRectMake(-1, -1, CGRectGetWidth(self.audioPubUnpubButton.frame) + 5,
                                       CGRectGetHeight(self.audioPubUnpubButton.frame) + 2);
        
		// Archiving overlay
		self.archiveOverlay.frame =
        CGRectMake(0, self.view.frame.size.height - (PUBLISHER_BAR_HEIGHT + ARCHIVE_BAR_HEIGHT),
                   self.view.frame.size.width, ARCHIVE_BAR_HEIGHT);
        
		[videoContainerView setContentSize:
         CGSizeMake(videoContainerView.frame.size.width * (connectionsCount ),
                    videoContainerView.frame.size.height)];
	}
	else if (orientation == UIInterfaceOrientationLandscapeLeft ||
             orientation == UIInterfaceOrientationLandscapeRight) {
		
        
		if (orientation == UIInterfaceOrientationLandscapeRight) {
			
            [videoContainerView setFrame:
			 CGRectMake(0, 0, self.view.frame.size.width - PUBLISHER_BAR_HEIGHT,
                        self.view.frame.size.height)];
            
			[_publisher.view setFrame:
			 CGRectMake(10, self.view.frame.size.height - (ARCHIVE_BAR_HEIGHT + 10 + 110), 144, 110)];
            
            self.bottomOverlayView.frame =
            CGRectMake(self.view.frame.size.width - PUBLISHER_BAR_HEIGHT, 0,
                       PUBLISHER_BAR_HEIGHT, self.view.frame.size.height);
            
			// Top overlay
			self.topOverlayView.frame =
            CGRectMake(0, 0, self.view.frame.size.width - PUBLISHER_BAR_HEIGHT,
                       self.topOverlayView.frame.size.height);
            
			// Archiving overlay
			self.archiveOverlay.frame =
            CGRectMake(0, self.view.frame.size.height - ARCHIVE_BAR_HEIGHT,
                       self.view.frame.size.width - PUBLISHER_BAR_HEIGHT, ARCHIVE_BAR_HEIGHT);
		}
		else
		{
			[videoContainerView setFrame:
			 CGRectMake(PUBLISHER_BAR_HEIGHT, 0, self.view.frame.size.width - PUBLISHER_BAR_HEIGHT,
                        self.view.frame.size.height)];
            
			[_publisher.view setFrame:
			 CGRectMake(10 + PUBLISHER_BAR_HEIGHT, self.view.frame.size.height -
                        (ARCHIVE_BAR_HEIGHT + 10 + 110), 144, 110)];
            
			self.bottomOverlayView.frame =
            CGRectMake(0, 0, PUBLISHER_BAR_HEIGHT, self.view.frame.size.height);
            
			self.topOverlayView.frame =
            CGRectMake(PUBLISHER_BAR_HEIGHT, 0, self.view.frame.size.width - PUBLISHER_BAR_HEIGHT,
                       self.topOverlayView.frame.size.height);
            
			// Archiving overlay
			self.archiveOverlay.frame =
            CGRectMake(PUBLISHER_BAR_HEIGHT, self.view.frame.size.height - ARCHIVE_BAR_HEIGHT,
                       self.view.frame.size.width - PUBLISHER_BAR_HEIGHT, ARCHIVE_BAR_HEIGHT);
		}
        
		// Mic button
		CGRect frame =  self.audioPubUnpubButton.frame;
		frame.origin.x = 0;
		frame.origin.y = 0;
		frame.size.width = PUBLISHER_BAR_HEIGHT;
		frame.size.height = 100;
        
		self.audioPubUnpubButton.frame = frame;
        
        // vertical border
		frame.origin.x = -1;
		frame.origin.y = -1;
		frame.size.width = 55;
		CALayer *borderLayer = [[self.audioPubUnpubButton.layer sublayers] objectAtIndex:1];
		borderLayer.frame = frame;
        
		// Camera button
		frame =  self.cameraToggleButton.frame;
		frame.origin.x = 0;
		frame.origin.y = self.bottomOverlayView.frame.size.height - 100;
		frame.size.width = PUBLISHER_BAR_HEIGHT;
		frame.size.height = 100;
        
		self.cameraToggleButton.frame = frame;
        
		frame.origin.x = -1;
		frame.origin.y = 0;
		frame.size.height = 90;
		frame.size.width = 55;
        
		borderLayer = [[self.cameraToggleButton.layer sublayers] objectAtIndex:1];
		borderLayer.frame = frame;
        
		// call button
		frame =  self.callButton.frame;
		frame.origin.x = 0;
		frame.origin.y = (self.bottomOverlayView.frame.size.height / 2) - (100 / 2);
		frame.size.width = PUBLISHER_BAR_HEIGHT;
		frame.size.height = 100;
        
		self.callButton.frame = frame;
        
		[videoContainerView setContentSize:CGSizeMake(videoContainerView.frame.size.width * connectionsCount,
                                                      videoContainerView.frame.size.height)];
	}
    
	if (isInFullScreen) {
        
        // call viewTapped to hide the views out of the screen.
		[[self topOverlayView].layer setValue:[NSNumber numberWithBool:NO] forKey:APP_IN_FULL_SCREEN];
		[self viewTapped:nil];
		[[self topOverlayView].layer setValue:[NSNumber numberWithBool:YES] forKey:APP_IN_FULL_SCREEN];
        
		self.topOverlayView.hidden = NO;
		self.bottomOverlayView.hidden = NO;
		self.archiveOverlay.hidden = NO;
	}
	
    // re arrange subscribers
	[self reArrangeSubscribers];
    
    // set video container offset to current subscriber
	[videoContainerView setContentOffset:CGPointMake(_currentSubscriber.view.tag * videoContainerView.frame.size.width, 0) animated:YES];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    
    // current subscriber
	int currentPage = (int)(videoContainerView.contentOffset.x / videoContainerView.frame.size.width);
    
	if (currentPage < [allConnectionsIds count]) {
        // show current scrolled subscriber
		NSString *connectionId = [allConnectionsIds objectAtIndex:currentPage];
		[self showAsCurrentSubscriber:[allSubscribers objectForKey:connectionId]];
	}
}

- (void)showAsCurrentSubscriber:(TBExampleSubscriber *)subscriber
{
	// unsubscribe currently running video
	_currentSubscriber.subscribeToVideo = NO;
	
    // update as current subscriber
    _currentSubscriber = subscriber;
	self.userNameLabel.text = _currentSubscriber.stream.name;
    
	// subscribe to new subscriber
	_currentSubscriber.subscribeToVideo = YES;
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
}

- (void)setupPublisher
{
	// create one time publisher and style publisher
	_publisher = [[TBExamplePublisher alloc] initWithDelegate:self];
    
	// set name of the publisher
	[_publisher setName:[[UIDevice currentDevice] name]];
    
	[_publisher.view setFrame:
	 CGRectMake(10, self.view.frame.size.height - (100 + 110), 144, 110)];
    
	[self.view addSubview:_publisher.view];
    
	// add pan gesture to publisher
	UIPanGestureRecognizer *pgr = [[UIPanGestureRecognizer alloc]
								   initWithTarget:self action:@selector(handlePan:)];
	[_publisher.view addGestureRecognizer:pgr];
	pgr.delegate = self;
	_publisher.view.userInteractionEnabled = YES;
	[pgr release];
}

- (IBAction)handlePan:(UIPanGestureRecognizer *)recognizer
{
	// user is panning publisher object
	CGPoint translation = [recognizer translationInView:_publisher.view];
    
	recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
										 recognizer.view.center.y + translation.y);
	[recognizer setTranslation:CGPointMake(0, 0) inView:_publisher.view];
}

#pragma mark - OpenTok Session
- (void)        session:(OTSession *)session
	connectionDestroyed:(OTConnection *)connection
{
	NSLog(@"connectionDestroyed: %@", connection);
}

- (void)      session:(OTSession *)session
	connectionCreated:(OTConnection *)connection
{
	NSLog(@"addConnection: %@", connection);
}

- (void)sessionDidConnect:(OTSession *)session
{
	[self.callButton setTitle:@"End" forState:UIControlStateNormal];
	[self.callButton setEnabled:YES];
    
    // now publish
	OTError *error;
	[_session publish:_publisher error:&error];
    if(error)
        [self showAlert:[error localizedDescription]];
}

- (void)reArrangeSubscribers
{
    
	CGFloat containerWidth = CGRectGetWidth(videoContainerView.bounds);
	CGFloat containerHeight = CGRectGetHeight(videoContainerView.bounds);
	int count = [allConnectionsIds count];
    
    // arrange all subscribers horizontally one by one.
	for (int i = 0; i < [allConnectionsIds count]; i++)
	{
		TBExampleSubscriber *subscriber = [allSubscribers valueForKey:[allConnectionsIds objectAtIndex:i]];
		[subscriber.view setFrame:
		 CGRectMake(i * CGRectGetWidth(videoContainerView.bounds), 0, containerWidth, containerHeight)];
	}
    
	[videoContainerView setContentSize:CGSizeMake(videoContainerView.frame.size.width * (count ), videoContainerView.frame.size.height)];
	[videoContainerView setContentOffset:CGPointMake(0, 0) animated:YES];
}

- (void)sessionDidDisconnect:(OTSession *)session
{
	[self.callButton setTitle:@"Call" forState:UIControlStateNormal];
    
    // remove all subscriber views from video container
	for (int i = 0; i < [allConnectionsIds count]; i++)
	{
		TBExampleSubscriber *subscriber = [allSubscribers valueForKey:[allConnectionsIds objectAtIndex:i]];
		[subscriber.view removeFromSuperview];
	}
    
	[_publisher.view removeFromSuperview];
    
	[allSubscribers removeAllObjects];
	[allConnectionsIds removeAllObjects];
	[allStreams removeAllObjects];
	[self.callButton setEnabled:YES];
    
	_currentSubscriber = NULL;
	[_publisher release];
	_publisher = nil;
}

- (void)    session:(OTSession *)session
	streamDestroyed:(OTStream *)stream
{
	NSLog(@"streamDestroyed %@", stream.connection.connectionId);
	
    // unsubscribe first
	TBExampleSubscriber *subscriber = [allSubscribers objectForKey:stream.connection.connectionId];

    OTError *error = nil;
	[_session unsubscribe:subscriber error:&error];
    if(error)
        [self showAlert:[error localizedDescription]];
    
	// remove from superview
	[subscriber.view removeFromSuperview];
    
	[allSubscribers removeObjectForKey:stream.connection.connectionId];
	[allConnectionsIds removeObject:stream.connection.connectionId];
    
	_currentSubscriber = nil;
	[self reArrangeSubscribers];
	
    // show first subscriber
    if ([allConnectionsIds count] > 0) {
		NSString *firstConnection = [allConnectionsIds objectAtIndex:0];
		[self showAsCurrentSubscriber:[allSubscribers objectForKey:firstConnection]];
	}
}

- (void)createSubscriber:(OTStream *)stream
{
	
    // create subscriber
	TBExampleSubscriber *subscriber = [[TBExampleSubscriber alloc] initWithStream:stream delegate:self];
    
	[allSubscribers setObject:subscriber forKey:stream.connection.connectionId];
	[allConnectionsIds addObject:stream.connection.connectionId];
    
    // set subscriber position and size
	CGFloat containerWidth = CGRectGetWidth(videoContainerView.bounds);
	CGFloat containerHeight = CGRectGetHeight(videoContainerView.bounds);
	int count = [allConnectionsIds count] - 1;
	[subscriber.view setFrame:CGRectMake(count * CGRectGetWidth(videoContainerView.bounds), 0, containerWidth, containerHeight)];
    
	subscriber.view.tag = count;
    
	subscriber.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    
    // add to video container view
	[videoContainerView insertSubview:subscriber.view belowSubview:_publisher.view];
    
    // subscribe now
    OTError *error = nil;
	[_session subscribe:subscriber error:&error];
    if(error)
        [self showAlert:[error localizedDescription]];
    
	// default subscribe video to the first subscriber only
	if (!_currentSubscriber) {
		[self showAsCurrentSubscriber:subscriber];
	} else {
		subscriber.subscribeToVideo = NO;
	}
    
	// set scrollview content width based on number of subscribers connected.
	[videoContainerView setContentSize:CGSizeMake(videoContainerView.frame.size.width * (count + 1),
												  videoContainerView.frame.size.height - 20)];
    
	[allStreams setObject:stream forKey:stream.connection.connectionId];
    
	[subscriber release];
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
	[self showAlert:[NSString stringWithFormat:@"There was an error connecting to session %@", session.sessionId]];
	[self callAction:nil];
}

- (void)publisher:(OTPublisher *)publisher didFailWithError:(OTError *)error
{
	NSLog(@"publisher didFailWithError %@", error);
	[self showAlert:[NSString stringWithFormat:@"There was an error publishing."]];
	[self callAction:nil];
}

- (void)subscriber:(OTSubscriber *)subscriber didFailWithError:(OTError *)error
{
	NSLog(@"subscriber could not connect to stream");
}

#pragma mark - Helper Methods
- (IBAction)callAction:(UIButton *)button
{
    
	if (_session && _session.sessionConnectionStatus == OTSessionConnectionStatusNotConnected) {
        // session not connected so connect now
		[_session connectWithToken:kToken error:nil];
		[self setupPublisher];
		[button setTitle:@"Connecting ..." forState:UIControlStateNormal];
		[button setEnabled:NO];
	}
    
	if (_session && _session.sessionConnectionStatus == OTSessionConnectionStatusConnected) {
        // disconnect session
		NSLog(@"disconnecting....");
		[_session disconnect:nil];
		[button setTitle:@"Disconnecting ..." forState:UIControlStateNormal];
		return;
	}
}

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Message from video session"
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
    
	[_callButton release];
	[_cameraSeparator release];
	[_micSeparator release];
	[_archiveOverlay release];
	[_archiveStatusLbl release];
	[_archiveStatusImgView release];
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

- (void)publisher:(OTPublisherKit *)publisher archivingStatusChanged:(BOOL)isArchiving
{
	NSLog(@"publisher archivingStatusChanged %d", isArchiving);
    
	if (isArchiving) {
        // set animation images
		self.archiveStatusLbl.text = @"Archiving call";
		UIImage *imageOne = [UIImage imageNamed:@"archiving_on-10.png"];
		UIImage *imageTwo = [UIImage imageNamed:@"archiving_pulse-Small.png"];
		NSArray *imagesArray = [NSArray arrayWithObjects:imageOne, imageTwo, nil];
		self.archiveStatusImgView.animationImages = imagesArray;
		self.archiveStatusImgView.animationDuration = 1.0f;
		self.archiveStatusImgView.animationRepeatCount = 0;
		[self.archiveStatusImgView startAnimating];
	} else {
		[self.archiveStatusImgView stopAnimating];
		self.archiveStatusLbl.text = @"Archiving off";
		self.archiveStatusImgView.image = [UIImage imageNamed:@"archiving_off-Small.png"];
	}
}

@end