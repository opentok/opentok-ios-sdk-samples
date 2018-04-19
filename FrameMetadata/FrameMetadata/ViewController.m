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

@interface ViewController ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate, TBRendererDelegate, TBFrameCapturerMetadataDelegate>
@property (weak, nonatomic) IBOutlet UILabel *metadataLabel;
@end

@implementation ViewController {
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    
    TBExampleVideoCapture* _defaultVideoCapture;
    
    TBExampleVideoRender* _subscriberVideoRenderView;
    TBExampleVideoRender* _publisherVideoRenderView;
}
static double widgetHeight = 240;
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
    return UIUserInterfaceIdiomPhone != [[UIDevice currentDevice] userInterfaceIdiom];
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
    OTPublisherSettings *pubSettings = [[OTPublisherSettings alloc] init];
    pubSettings.name = [[UIDevice currentDevice] name];
    _publisher = [[OTPublisher alloc]
                  initWithDelegate:self settings:pubSettings];
    
    TBExampleVideoCapture* videoCapture =
    [[TBExampleVideoCapture alloc] init];
    
    __weak ViewController *weakSelf = self;
    [videoCapture setDelegate:weakSelf];
    [_publisher setVideoCapture:videoCapture];
    
    _publisherVideoRenderView =
    [[TBExampleVideoRender alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
    _publisherVideoRenderView.delegate = self;
    // Set mirroring only if the front camera is being used.
    [_publisherVideoRenderView setMirroring:
     (AVCaptureDevicePositionFront == videoCapture.cameraPosition)];
    [_publisher setVideoRender:_publisherVideoRenderView];
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }

    [_publisherVideoRenderView setFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
    [self.view addSubview:_publisherVideoRenderView];
}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    [_publisherVideoRenderView clearRenderBuffer];
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
    _subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    _subscriberVideoRenderView =
    [[TBExampleVideoRender alloc] initWithFrame:CGRectMake(0,0,1,1)];
    _subscriberVideoRenderView.delegate = self;
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
    [_subscriberVideoRenderView setFrame:CGRectMake(0, widgetHeight, widgetWidth,
                                         widgetHeight)];
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

- (void)renderer:(TBExampleVideoRender*)renderer
 didReceiveFrame:(OTVideoFrame*)frame {
    if (renderer == _publisher.videoRender) {
        NSData *metadata = frame.metadata;
        NSString *timestamp = [[NSString alloc] initWithData:metadata encoding:NSUTF8StringEncoding];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.metadataLabel setText:timestamp];
            NSLog(@"Receiving publisher metadata: %@", timestamp);
        });
    }
    else if (renderer == _subscriber.videoRender) {
        NSLog(@"Receiving subscriber metadata");
    }
}

- (void)finishPreparingFrame:(OTVideoFrame *)videoFrame {
    [self setTimestampToVideoFrame:videoFrame];
}

- (void)setTimestampToVideoFrame:(OTVideoFrame *)videoFrame {
    if (!videoFrame) {
        return;
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];
    
    NSData *metadata = [timestamp dataUsingEncoding:NSUTF8StringEncoding];
    OTError *error = nil;
    [videoFrame setMetadata:metadata error:&error];
    if (error) {
        NSLog(@"Append metadata error: %@", error);
    }
}

@end
