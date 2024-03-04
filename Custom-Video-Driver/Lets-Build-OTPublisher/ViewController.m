//
//  ViewController.m
//  Lets-Build-Publisher
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "TBExampleVideoCapture.h"
#import "TBExampleVideoRender.h"
#import "TBExampleMultiCamCapture.h"
#import "TBCaptureMultiCamFactory.h"

// Set 1 for multi camera session, which uses
// two publishers publishing from front and rear cameras at the same time
// iOS supports multi cam only on higher end devices (e.g, >= A12 CPU)
// The capturer will return nil if you try to run multi cam samples on an unsupported device!
#define USE_MULTICAM_SESSION 0

@interface OTSession ()
    
- (void)setApiRootURL:(NSURL *)aURL;
    
@end

@interface ViewController ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate>

@end

@implementation ViewController {
    OTSession* _session;
    OTPublisher* _frontCamPublisher;
    OTPublisher* _rearCamPublisher;
    OTSubscriber* _subscriber;
    
    TBExampleVideoRender* _subscriberVideoRenderView;
    TBExampleVideoRender* _frontCamPublisherVideoRenderView;
    TBExampleVideoRender* _rearCamPublisherVideoRenderView;
    
}
static double widgetHeight = 180;
static double widgetWidth = 320;

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"";
// Replace with your generated session ID
static NSString* const kSessionId = @"";
// Replace with your generated token
static NSString* const kToken = @"";

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([kApiKey isEqualToString:@""] || [kSessionId isEqualToString:@""] || [kToken isEqualToString:@""]) {
        NSLog(@"Session credentials not set");
        return;
    }
    
    // Step 1: As the view comes into the foreground, initialize a new instance
    // of OTSession and begin the connection process.
    _session = [[OTSession alloc] initWithApiKey:kApiKey
                                       sessionId:kSessionId
                                           delegate:self];

    [self doConnect];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:
(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if (UIUserInterfaceIdiomPhone == [[UIDevice currentDevice]
                                      userInterfaceIdiom])
    {
        return NO;
    } else {
        return YES;
    }
}
#pragma mark - OpenTok methods

/**
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
- (void)doConnect
{
    OTError *error = nil;
    [_session connectWithToken:kToken error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
}

/**
 * Sets up an instance of OTPublisher to use with this session. OTPubilsher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void)doPublishWithFrontCam
{
    // Front Camera Publisher
    OTPublisherSettings *pubSettings = [[OTPublisherSettings alloc] init];
    pubSettings.name = [[UIDevice currentDevice] name];

    TBExampleVideoCapture *videoCapture = nil;
    if(USE_MULTICAM_SESSION == 1)
        videoCapture = (TBExampleVideoCapture *) [[TBCaptureMultiCamFactory sharedInstance]
                                                  createCapturerForCameraPosition:AVCaptureDevicePositionFront];

    else
        videoCapture = [[TBExampleVideoCapture alloc] init];

    pubSettings.videoCapture = videoCapture;
    _frontCamPublisher = [[OTPublisher alloc]
                          initWithDelegate:self settings:pubSettings];

   _frontCamPublisherVideoRenderView =
    [[TBExampleVideoRender alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];

    // Set mirroring only if the front camera is being used.
    [_frontCamPublisherVideoRenderView setMirroring:YES];
    [_frontCamPublisher setVideoRender:_frontCamPublisherVideoRenderView];

    OTError *error = nil;
    [_session publish:_frontCamPublisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

    [_frontCamPublisherVideoRenderView setFrame:CGRectMake(0, (_rearCamPublisher) ? widgetHeight : 0, widgetWidth, widgetHeight)];
    [self.view addSubview:_frontCamPublisherVideoRenderView];
}

- (void)doPublishWithRearCam
{
    // Back Camera Publisher
    OTPublisherSettings *pubSettings = [[OTPublisherSettings alloc] init];
    pubSettings.name = [[UIDevice currentDevice] name];
    TBExampleMultiCamCapture* videoCapture = [[TBCaptureMultiCamFactory sharedInstance]
                                              createCapturerForCameraPosition:AVCaptureDevicePositionBack];

    pubSettings.videoCapture = videoCapture;
    _rearCamPublisher = [[OTPublisher alloc]
                          initWithDelegate:self settings:pubSettings];
    
   _rearCamPublisherVideoRenderView =
    [[TBExampleVideoRender alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    // Set mirroring only if the front camera is being used.
    [_rearCamPublisherVideoRenderView setMirroring:false];
     
    [_rearCamPublisher setVideoRender:_rearCamPublisherVideoRenderView];
    
    OTError *error = nil;
    [_session publish:_rearCamPublisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

    [_rearCamPublisherVideoRenderView setFrame:CGRectMake(0, (_frontCamPublisher) ? widgetHeight : 0, widgetWidth, widgetHeight)];
    [self.view addSubview:_rearCamPublisherVideoRenderView];
}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    [_frontCamPublisherVideoRenderView clearRenderBuffer];
    [_frontCamPublisher.view removeFromSuperview];
    _frontCamPublisher = nil;

    [_rearCamPublisherVideoRenderView clearRenderBuffer];
    [_rearCamPublisher.view removeFromSuperview];
    _rearCamPublisher = nil;

    // this is a good place to notify the end-user that publishing has stopped.
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish,
 * this method does not add the subscriber to the view hierarchy. Instead, we
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void)doSubscribe:(OTStream*)stream
{
    _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    _subscriberVideoRenderView =
    [[TBExampleVideoRender alloc] initWithFrame:CGRectMake(0,0,1,1)];
    [_subscriber setVideoRender:_subscriberVideoRenderView];
    
    OTError *error = nil;
    [_session subscribe:_subscriber error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

}

/**
 * Cleans the subscriber from the view hierarchy, if any.
 * NB: You do *not* have to call unsubscribe in your controller in response to
 * a streamDestroyed event. Any subscribers (or the publisher) for a stream will
 * be automatically removed from the session during cleanup of the stream.
 */
- (void)cleanupSubscriber
{
    [_subscriberVideoRenderView clearRenderBuffer];
    [_subscriber.view removeFromSuperview];
    _subscriber = nil;
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    
    // Step 2: We have successfully connected, now instantiate a publisher and
    // begin pushing A/V streams into OpenTok.
    [self doPublishWithFrontCam];
    if(USE_MULTICAM_SESSION == 1)
        [self doPublishWithRearCam];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
}

- (void)session:(OTSession*)mySession
  streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    
    // Step 3a: Begin subscribing to a stream we
    // have seen on the OpenTok session.
    if (nil == _subscriber)
    {
        [self doSubscribe:stream];
    }
}

- (void)session:(OTSession*)session
streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
}

- (void)  session:(OTSession *)session
connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void)    session:(OTSession *)session
connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
    if ([_subscriber.stream.connection.connectionId
         isEqualToString:connection.connectionId])
    {
        [self cleanupSubscriber];
    }
}

- (void) session:(OTSession*)session
didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    [_subscriberVideoRenderView setFrame:CGRectMake(0, (_rearCamPublisher ? widgetHeight * 2: widgetHeight), widgetWidth, widgetHeight)];
    [self.view addSubview:_subscriberVideoRenderView];
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    NSLog(@"Publishing");
}

- (void)publisher:(OTPublisherKit*)publisher
  streamDestroyed:(OTStream *)stream
{
    if ([_subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
    
    [self cleanupPublisher];
    
    NSLog(@"publisher destroyed");
}

- (void)publisher:(OTPublisherKit*)publisher
 didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
}

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"OTError"
                                                                         message:string
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertVC animated:YES completion:nil];
    });
}

@end
