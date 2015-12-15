//
//  ViewController.m
//  Default-Camera-Capturer
//
//  Created by Chetan Angadi on 12/14/15.
//  Copyright © 2015 TokBox. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>

@interface ViewController ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate,OTSubscriberKitNetworkStatsDelegate>

@end

@implementation ViewController {
    OTSession *_session;
    OTPublisher *_publisher;
    OTSubscriber *_subscriber;
}
static double widgetHeight = 240;
static double widgetWidth = 320;

// Change to NO to subscribe to streams other than your own.
static bool subscribeToSelf = YES;

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"";
// Replace with your generated session ID
static NSString* const kSessionId = @"";
// Replace with your generated token
static NSString* const kToken = @"";

# pragma mark View LifeCycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

# pragma mark - OTSession delegate callbacks

- (void) sessionDidConnect:(OTSession *)session {
    NSLog(@"Connected to session %@", session.sessionId);
    // Step 2: We have successfully connected, now instantiate a publisher and
    // begin pushing A/V streams into OpenTok.
    [self doPublish];
}

- (void) sessionDidDisconnect:(OTSession *)session {
    NSLog(@"Session Disconnected with session id %@", session.sessionId);
}

- (void) session:(OTSession *)session
didFailWithError:(OTError *)error {
    NSLog(@"Session failed with error %@", error);
}

- (void) session:(OTSession *)session
   streamCreated:(OTStream *)stream {
    // Step 3a: (if NO == subscribeToSelf): Begin subscribing to a stream we
    // have seen on the OpenTok session.
    if(nil == _subscriber && !subscribeToSelf) {
        [self doSubscribe:stream];
    }
}

- (void) session:(OTSession *)session
 streamDestroyed:(OTStream *)stream {
    NSLog(@"Stream destroyed %@", stream.connection.connectionId);
    
}

- (void) session:(OTSession *)session connectionCreated:(OTConnection *)connection {
    NSLog(@"Connection created");
}

- (void) session:(OTSession *)session connectionDestroyed:(OTConnection *)connection {
    [self cleanUpSubscriber];
}

# pragma mark - OTPublisher delegate callbacks

- (void) publisher:(OTPublisherKit *)publisher
  didFailWithError:(OTError *)error {
    NSLog(@" Publisher failed with error ");
    [self cleanUpPublisher];
}

- (void)publisher:(OTPublisherKit*)publisher
    streamCreated:(OTStream*)stream {
    
    // Step 3b: (if YES == subscribeToSelf): Our own publisher is now visible to
    // all participants in the OpenTok session. We will attempt to subscribe to
    // our own stream. Expect to see a slight delay in the subscriber video and
    // an echo of the audio coming from the device microphone.
    if(nil == _subscriber && subscribeToSelf) {
        [self doSubscribe:stream];
    }
}

- (void) publisher:(OTPublisherKit *)publisher
   streamDestroyed:(OTStream *)stream {
    [self cleanUpPublisher];
}

- (void) cleanUpPublisher {
    [_publisher.view removeFromSuperview];
    _publisher = nil;
}

# pragma mark - OTSubscriber delegate callbacks

//Method is called back when subscriber is connected to stream
- (void) subscriberDidConnectToStream:(OTSubscriberKit *)subscriber {
    NSLog(@"Subscriber did conect to stream");
    assert(_subscriber == subscriber);
    [self.view addSubview:_subscriber.view];
    [_subscriber.view setFrame:CGRectMake(0, widgetHeight, widgetWidth, widgetHeight)];
}

- (void) subscriber:(OTSubscriberKit *)subscriber
   didFailWithError:(OTError *)error {
    NSLog(@"Subscriber failed with error %@", error);
}

- (void) subscriberDidDisconnectFromStream:(OTSubscriberKit *)subscriber {
    [self cleanUpSubscriber];
}


/**
 * Cleans the subscriber from the view hierarchy, if any.
 * NB: You do *not* have to call unsubscribe in your controller in response to
 * a streamDestroyed event. Any subscribers (or the publisher) for a stream will
 * be automatically removed from the session during cleanup of the stream.
 */
- (void) cleanUpSubscriber {
    [_subscriber.view removeFromSuperview];
    _subscriber = nil;
}


#pragma mark - ViewController methods
/**
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
- (void) doConnect {
    OTError * __autoreleasing error = nil;
    [_session connectWithToken:kToken error:&error];
    
    if(error) {
        [self showAlert:[error localizedDescription]];
    }
}

/**
 * Sets up an instance of OTPublisher to use with this session. OTPublisher
 * binds to the device camera and microphone, and will provide A/V streams
 * to the OpenTok session.
 */
- (void) doPublish {
    
    //In publisher constructor you can specify the resolution and stream framerate
    //publisher should publish with
    _publisher = [[OTPublisher alloc] initWithDelegate:self
                                                  name:@"DefaultCameraCapturer"
                                      cameraResolution:OTCameraCaptureResolutionMedium
                                       cameraFrameRate:OTCameraCaptureFrameRate30FPS];
    OTError * __autoreleasing error = nil;
    [_session publish:_publisher error:&error];
    if(error) {
        [self showAlert:[error localizedDescription]];
    }
    
    [self.view addSubview:_publisher.view];
    [_publisher.view setFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish,
 * this method does not add the subscriber to the view hierarchy. Instead, we
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void) doSubscribe:(OTStream *)stream {
    _subscriber = [[OTSubscriber alloc] initWithStream:stream
                                              delegate:self];
    OTError * __autoreleasing error = nil;
    [_session subscribe:_subscriber
                  error:&error];
    if(error) {
        [self showAlert:[error localizedDescription]];
    }
}

//Alerts with error
- (void) showAlert:(NSString *) string {
    
    // show alertview on main UI
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"OTError"
                                                        message:string
                                                       delegate:self
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil] ;
        [alert show];
    });
}
@end
