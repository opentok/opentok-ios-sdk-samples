//
//  ViewController.m
//  Screen-Sharing
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import "TBScreenCapture.h"
#import <OpenTok/OpenTok.h>

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"";
// Replace with your generated session ID
static NSString* const kSessionId = @"";
// Replace with your generated token
static NSString* const kToken = @"";

@interface ViewController () <OTSessionDelegate, OTPublisherDelegate, OTSubscriberDelegate>
@property (nonatomic) IBOutlet UITextField *timeDisplay;
@property (nonatomic) OTSession *session;
@property (nonatomic) OTPublisher *publisher;
@property (nonatomic) OTSubscriber *subscriber;
@property (nonatomic) dispatch_queue_t queue;
@property (nonatomic) dispatch_source_t timer;
@end

static double widgetHeight = 240 / 2;
static double widgetWidth = 320 / 2;

@implementation ViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Setup a timer to periodically update the UI. This gives us something
    // dynamic that we can see on the receiver's end to verify everything works.
    self.queue = dispatch_queue_create("ticker-timer", 0);
    self.timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    dispatch_source_set_timer(self.timer, dispatch_walltime(NULL, 0),
                              10ull * NSEC_PER_MSEC, 1ull * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(self.timer, ^{
        double timestamp = [[NSDate date] timeIntervalSince1970];
        int64_t timeInMilisInt64 = (int64_t)(timestamp*1000);
        
        NSString *mills = [NSString stringWithFormat:@"%lld", timeInMilisInt64];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.timeDisplay setText:mills];
        });
    });
    
    dispatch_resume(self.timer);
    
    self.session = [[OTSession alloc] initWithApiKey:kApiKey
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

#pragma mark - OpenTok methods

- (void)doConnect
{
    OTError *error = nil;
    
    [self.session connectWithToken:kToken error:&error];
    if (error) {
        [self showAlert:[error localizedDescription]];
    }
}

- (void)doPublish
{
    // Setup the publisher with customizations for screencasting. You might
    // consider setting this up as an OTPublisherKit subclass, but it's here
    // for brevity and consolidation.
    
    // We're not using Audio for this publisher, so don't bother setting up the
    // audio track.
    OTPublisherSettings *settings = [[OTPublisherSettings alloc] init];
    settings.name = [UIDevice currentDevice].name;
    settings.audioTrack = YES;
    settings.videoTrack = YES;
    self.publisher = [[OTPublisher alloc] initWithDelegate:self settings:settings];
    
    // Additionally, the publisher video type can be updated to signal to
    // receivers that the video is from a screencast. This value also disables
    // some downsample scaling that is used to adapt to changing network
    // conditions. We will send at a lower framerate to compensate for this.
    [self.publisher setVideoType:OTPublisherKitVideoTypeScreen];
    
    // This disables the audio fallback feature when using routed sessions.
    self.publisher.audioFallbackEnabled = NO;

    // Finally, wire up the video source.
    TBScreenCapture* videoCapture =
    [[TBScreenCapture alloc] initWithView:self.view];
    [self.publisher setVideoCapture:videoCapture];
    
    OTError *error = nil;
    [self.session publish:self.publisher error:&error];
    if (error) {
        [self showAlert:[error localizedDescription]];
    }
}

- (void)cleanupPublisher {
    self.publisher = nil;
}

/**
 * Instantiates a subscriber for the given stream and asynchronously begins the
 * process to begin receiving A/V content for this stream. Unlike doPublish,
 * this method does not add the subscriber to the view hierarchy. Instead, we
 * add the subscriber only after it has connected and begins receiving data.
 */
- (void)doSubscribe:(OTStream*)stream
{
    self.subscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
    
    OTError *error = nil;
    [self.session subscribe:self.subscriber error:&error];
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
    [self.subscriber.view removeFromSuperview];
    self.subscriber = nil;
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


- (void)session:(OTSession*)mySession streamCreated:(OTStream *)stream
{
    NSLog(@"session streamCreated (%@)", stream.streamId);
    // Step 3a: Begin subscribing to a stream we
    // have seen on the OpenTok session.
    if (nil == self.subscriber)
    {
        [self doSubscribe:stream];
    }
}

- (void)session:(OTSession*)session streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
    if ([self.subscriber.stream.streamId isEqualToString:stream.streamId])
    {
        [self cleanupSubscriber];
    }
}

- (void) session:(OTSession *)session
connectionCreated:(OTConnection *)connection
{
    NSLog(@"session connectionCreated (%@)", connection.connectionId);
}

- (void) session:(OTSession *)session
connectionDestroyed:(OTConnection *)connection
{
    NSLog(@"session connectionDestroyed (%@)", connection.connectionId);
    if ([self.subscriber.stream.connection.connectionId
         isEqualToString:connection.connectionId])
    {
        [self cleanupSubscriber];
    }
}

- (void) session:(OTSession*)session didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    assert(self.subscriber == subscriber);
    [self.subscriber.view setFrame:CGRectMake(0, 0, widgetWidth,
                                          widgetHeight)];
    [self.view addSubview:self.subscriber.view];
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

- (void)subscriberVideoDataReceived:(OTSubscriber*)subscriber
{
    //NSLog(@"subscriberVideoDataReceived");
}

# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit*)publisher streamDestroyed:(OTStream *)stream
{
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisherKit*)publisher didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisherKit *)publisher
    streamCreated:(OTStream *)stream
{
    NSLog(@"Publishing");
}

- (void)showAlert:(NSString *)string
{
	dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"OTError"
                                                                         message:string
                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertVC animated:YES completion:nil];
    });
}

@end
