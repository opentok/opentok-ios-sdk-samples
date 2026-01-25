//
//  ViewController.m
//  Ringtones
//
//  Created by Charley Robinson on 2/16/16.
//  Copyright © 2016 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "OTAudioDeviceRingtone.h"

@interface ViewController() <OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate>
@property (nonatomic) OTSession *session;
@property (nonatomic) OTPublisher *publisher;
@property (nonatomic) OTSubscriber *subscriber;
@property (nonatomic) OTAudioDeviceRingtone *myAudioDevice;
@property (nonatomic) NSString *pubStreamId;
@end

@implementation ViewController
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
    
    NSString* path = [[NSBundle mainBundle] pathForResource:@"bananaphone"
                                                     ofType:@"mp3"];
    _myAudioDevice = [[OTAudioDeviceRingtone alloc] initWithRingtone:[NSURL URLWithString:path]];
    [OTAudioDeviceManager setAudioDevice:_myAudioDevice];
    
    _session = [[OTSession alloc] initWithApiKey:kApiKey
                                       sessionId:kSessionId
                                        delegate:self];
    
    [self doConnectWithToken:kToken];
}

- (void) startOrStopRingtone{
    if ([_myAudioDevice isRingTonePlaying]) {
        [_myAudioDevice stopRingtone];
    } else {
        [_myAudioDevice startRingtone];
    }
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate {
    return UIUserInterfaceIdiomPhone != [[UIDevice currentDevice] userInterfaceIdiom];
}
#pragma mark - OpenTok methods

/**
 * Asynchronously begins the session connect process. Some time later, we will
 * expect a delegate method to call us back with the results of this action.
 */
- (void)doConnectWithToken:(NSString*)token
{
    OTError *error = nil;
    
    [_session connectWithToken:token error:&error];
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
    OTPublisherSettings *settings = [[OTPublisherSettings alloc] init];
    settings.name = [UIDevice currentDevice].name;
    _publisher = [[OTPublisher alloc] initWithDelegate:self settings:settings];
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        [self showAlert:[error localizedDescription]];
    }
    
    [self.view addSubview:_publisher.view];
    [_publisher.view setFrame:CGRectMake(0, 0, widgetWidth, widgetHeight)];
    //start ringtone
    [self startOrStopRingtone];
}

/**
 * Cleans up the publisher and its view. At this point, the publisher should not
 * be attached to the session any more.
 */
- (void)cleanupPublisher {
    [_session unpublish:_publisher error:nil];
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
    [_session unsubscribe:_subscriber error:nil];
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
    if (_publisher) {
        [self cleanupPublisher];
    }
    if (_subscriber) {
        [self cleanupSubscriber];
    }
    if ([_myAudioDevice isRingTonePlaying]) {
        [_myAudioDevice stopRingtone];
    }
    _session = nil;
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
    // sometimes the old stream comes in and
    // stops the new stream from playing ringtone, when restarted. This happens
    // because  media server assumes a drop connection and disconnects after some time
    // has gone by.
    if (![subscriber.stream.streamId isEqualToString:self.pubStreamId]){
        return;
    }
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    
    // Stop ringtone from playing, as the subscriber will connect shortly
    [self startOrStopRingtone];
    
    assert(_subscriber == subscriber);
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

- (void)subscriberDidDisconnectFromStream:(OTSubscriberKit *)subscriber
{
    NSLog(@"subscriberDidDisconnectFromStream %@", subscriber);
    [self cleanupSubscriber];
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    NSLog(@"Publishing");
    self.pubStreamId = stream.streamId;
    // play the ringtone for 10 seconds , it is fun...
    // doSubscribe method will stop it later
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self doSubscribe:stream];
    });
}

- (void)publisher:(OTPublisherKit*)publisher
  streamDestroyed:(OTStream *)stream
{
    NSLog(@"publisher %@ streamDestroyed %@", publisher, stream);
    
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

@end
