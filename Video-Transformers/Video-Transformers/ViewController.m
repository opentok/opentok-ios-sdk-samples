//
//  ViewController.m
//  Hello-World
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"47521351";
// Replace with your generated session ID
static NSString* const kSessionId = @"2_MX40NzUyMTM1MX5-MTY4NTM2NjAyNTQwMn4rY0xNQjVUcENIWWd1UUVhazBjSDA4WWd-fn4";
// Replace with your generated token
static NSString* const kToken = @"T1==cGFydG5lcl9pZD00NzUyMTM1MSZzaWc9YjVmY2QxM2Q5NjJmYmRlMmQ2Y2JlMjczYzUwN2FhYzRmYjVhOWM2YzpzZXNzaW9uX2lkPTJfTVg0ME56VXlNVE0xTVg1LU1UWTROVE0yTmpBeU5UUXdNbjRyWTB4TlFqVlVjRU5JV1dkMVVVVmhhekJqU0RBNFdXZC1mbjQmY3JlYXRlX3RpbWU9MTY4NTM2NjA3MiZub25jZT0wLjQyMDk3NTY1OTEwNjE2Mzc1JnJvbGU9cHVibGlzaGVyJmV4cGlyZV90aW1lPTE2ODc5NTgwNzEmaW5pdGlhbF9sYXlvdXRfY2xhc3NfbGlzdD0=";

@interface ViewController ()<OTSessionDelegate, OTSubscriberDelegate, OTPublisherDelegate>
@property (nonatomic) OTSession *session;
@property (nonatomic) OTPublisher *publisher;
@property (nonatomic) OTSubscriber *subscriber;
@end

@interface custom_border : NSObject <OTCustomVideoTransformer>

@end


@implementation custom_border
- (void)transform:(nonnull OTVideoFrame *)videoFrame {
    OTPixelFormat pixelFormat = videoFrame.format.pixelFormat;
    int strides[] =
    {
        [videoFrame getPlaneStride:0],
        [videoFrame getPlaneStride:2],
        [videoFrame getPlaneStride:1]
    };
    uint8_t* planes[] =
    {
        [videoFrame getPlaneBinaryData:0],
        [videoFrame getPlaneBinaryData:2],
        [videoFrame getPlaneBinaryData:1]
    };
    [videoFrame convertInPlace:pixelFormat planes:planes strides:strides];
}
@end

custom_border* border;

@implementation ViewController
static double widgetHeight = 240;
static double widgetWidth = 320;

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

- (BOOL)shouldAutorotate {
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

    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            
            NSError *error1 = nil;
            NSArray *bundleContents = [fileManager contentsOfDirectoryAtPath:bundlePath error:&error1];
            
            if (error1) {
                NSLog(@"Error reading bundle contents: %@", error);
                return;
            }
            
            for (NSString *filename in bundleContents) {
                if ([[filename pathExtension] isEqualToString:@"tflite"]) {
                    NSLog(@"%@", filename);
                }
            }
    OTVideoTransformer *BackgroundBlur = [[OTVideoTransformer alloc] initWithName:@"BackgroundBlur" properties:@"{\"radius\":\"High\"}"];
        
    // Custom transformers
    border = [custom_border alloc];
    OTVideoTransformer *border_transformer = [[OTVideoTransformer alloc] initWithName:@"border" transformer:border];

    NSMutableArray * myVideoTransformers = [[NSMutableArray alloc] init];

    [myVideoTransformers addObject:BackgroundBlur];
    [myVideoTransformers addObject:border_transformer];

    _publisher.videoTransformers = [[NSMutableArray alloc] initWithArray:myVideoTransformers];

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

@end
