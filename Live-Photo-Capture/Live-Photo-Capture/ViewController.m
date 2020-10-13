//
//  ViewController.m
//  Live-Photo-Capture
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "TBExamplePhotoVideoCapture.h"

@interface ViewController() <OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate>
@property (nonatomic) OTSession *session;
@property (nonatomic) OTPublisher *publisher;
@property (nonatomic) OTSubscriber *subscriber;
@property (nonatomic) UIImageView *myImageView;
@property (nonatomic) TBExamplePhotoVideoCapture *myPhotoVideoCaptureModule;
@end

@implementation ViewController
static double widgetHeight = 120;
static double widgetWidth = 160;

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"46951484";
// Replace with your generated session ID
static NSString* const kSessionId = @"2_MX40Njk1MTQ4NH5-MTYwMjU5NjI5OTQzMX5hYWtkV1JEWU9rcHcxZXd6ai9DT3IwUjV-fg";
// Replace with your generated token
static NSString* const kToken = @"T1==cGFydG5lcl9pZD00Njk1MTQ4NCZzaWc9ZjQ3MzJiN2UwZjg0ODRiY2QwODBmNmM5YjMyY2Q4ODU2ZjQyN2I4OTpzZXNzaW9uX2lkPTJfTVg0ME5qazFNVFE0Tkg1LU1UWXdNalU1TmpJNU9UUXpNWDVoWVd0a1YxSkVXVTlyY0hjeFpYZDZhaTlEVDNJd1VqVi1mZyZjcmVhdGVfdGltZT0xNjAyNTk2MzI3Jm5vbmNlPTAuNjE2NTMwODg2MTk3MDY0JnJvbGU9cHVibGlzaGVyJmV4cGlyZV90aW1lPTE2MDI2ODI3MjYmaW5pdGlhbF9sYXlvdXRfY2xhc3NfbGlzdD0=";

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Make a UIImageView to hold the output of the photo snapshot
    _myImageView = [[UIImageView alloc]
                    initWithFrame:CGRectMake(widgetWidth, 0, widgetHeight,
                                             widgetWidth)];
    [self.view addSubview:_myImageView];
    
    // Bind the whole screen to a gesture recognizer - tap on the screen and
    //  we'll take a picture!
    UITapGestureRecognizer *singleFingerTap =
    [[UITapGestureRecognizer alloc] initWithTarget:self
                                            action:@selector(handleSingleTap:)];
    [self.view addGestureRecognizer:singleFingerTap];
    [singleFingerTap release];
    
    _session = [[OTSession alloc] initWithApiKey:kApiKey
                                       sessionId:kSessionId
                                           delegate:self];
    [self doConnect];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate {
    return UIUserInterfaceIdiomPhone != [[UIDevice currentDevice] userInterfaceIdiom];
}

#pragma mark - Gesture recognizer

/**
 * Fired if the end user taps on the screen. We'll invoke the capture module
 * to take a picture, then display the results.
 */
- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
    if (_myPhotoVideoCaptureModule.isTakingPhoto) {
        return;
    }
    [_myPhotoVideoCaptureModule takePhotoWithCompletionHandler:
     ^(UIImage* image) {
        [_myImageView setImage:image];
        [_myImageView setNeedsDisplay];
    }];
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
- (void)doPublish
{
    // In this example, we'll be using our own video capture module that can
    // also support photo-quality image capture.
    _myPhotoVideoCaptureModule = [[TBExamplePhotoVideoCapture alloc] init];
    OTPublisherSettings* pubSettings = [[OTPublisherSettings alloc] init];
    pubSettings.name = [[UIDevice currentDevice] name];
    pubSettings.videoCapture = _myPhotoVideoCaptureModule;
    _publisher = [[OTPublisher alloc] initWithDelegate:self settings:pubSettings];
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

    [_publisher.view setFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
    [self.view addSubview:_publisher.view];
}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    [_publisher.view removeFromSuperview];
    _publisher = nil;
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
    _subscriber = [[OTSubscriber alloc] initWithStream:stream
                                                     delegate:self];
    OTError *error = nil;;
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
    [_subscriber.view removeFromSuperview];
    _subscriber = nil;
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    NSLog(@"sessionDidConnect (%@)", session.sessionId);
    
    [self doPublish];
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
    [_subscriber.view setFrame:CGRectMake(0, widgetHeight, widgetWidth,
                                          widgetHeight)];
    [self.view addSubview:_subscriber.view];
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
}

- (void)publisher:(OTPublisherKit*)publisher
 didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
}

- (void)showAlert:(NSString *)string
{
    // show alertview on main UI
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"Message from video session"
                                                                         message:string
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertVC animated:YES completion:nil];
    });
}

@end
