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
static NSString* const kApiKey = @"";
// Replace with your generated session ID
static NSString* const kSessionId = @"";
// Replace with your generated token
static NSString* const kToken = @"";

@interface ViewController ()<OTSessionDelegate, OTSubscriberDelegate, OTPublisherDelegate>
@property (nonatomic) OTSession *session;
@property (nonatomic) OTPublisher *publisher;
@property (nonatomic) OTSubscriber *subscriber;
@end

@implementation ViewController
static double widgetHeight = 240;
static double widgetWidth = 320;

UIButton *buttonSwapCamera;
UIButton *buttonTorch;
UIButton *buttonZoom;

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
    
    CGFloat buttonCount = 3.0;
    CGFloat padding = 10.0;
    CGFloat totalPadding = (buttonCount + 1) * padding;
    CGFloat buttonWidth = (widgetWidth - totalPadding) / buttonCount;
    CGFloat buttonHeight = 30.0;
    CGFloat yPos = 15.0;
    
    // Configure Swap Camera button
    buttonSwapCamera = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonSwapCamera.frame = CGRectMake(padding, yPos, buttonWidth, buttonHeight);
    buttonSwapCamera.layer.cornerRadius = 5.0;
    [self.view addSubview:buttonSwapCamera];
    [self.view bringSubviewToFront:buttonSwapCamera];
    [buttonSwapCamera setTitle:@"Swap" forState:UIControlStateNormal];
    buttonSwapCamera.titleLabel.font = [UIFont systemFontOfSize:12];
    [buttonSwapCamera setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    buttonSwapCamera.backgroundColor = [UIColor whiteColor];
    buttonSwapCamera.layer.borderWidth = 1.0;
    buttonSwapCamera.layer.borderColor = [UIColor grayColor].CGColor;
    [buttonSwapCamera addTarget:self action:@selector(buttonSwapTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // Configure Torch button
    buttonTorch = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonTorch.frame = CGRectMake(padding * 2 + buttonWidth, yPos, buttonWidth, buttonHeight);
    buttonTorch.layer.cornerRadius = 5.0;
    [self.view addSubview:buttonTorch];
    [self.view bringSubviewToFront:buttonTorch];
    [buttonTorch setTitle:@"Torch" forState:UIControlStateNormal];
    buttonTorch.titleLabel.font = [UIFont systemFontOfSize:12];
    [buttonTorch setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    buttonTorch.backgroundColor = [UIColor whiteColor];
    buttonTorch.layer.borderWidth = 1.0;
    buttonTorch.layer.borderColor = [UIColor grayColor].CGColor;
    [buttonTorch addTarget:self action:@selector(buttonTorchTapped:) forControlEvents:UIControlEventTouchUpInside];

    // Configure Zoom button
    buttonZoom = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonZoom.frame = CGRectMake(padding * 3 + buttonWidth * 2, yPos, buttonWidth, buttonHeight);
    buttonZoom.layer.cornerRadius = 5.0;
    [self.view addSubview:buttonZoom];
    [self.view bringSubviewToFront:buttonZoom];
    [buttonZoom setTitle:@"Zoom" forState:UIControlStateNormal];
    buttonZoom.titleLabel.font = [UIFont systemFontOfSize:12];
    [buttonZoom setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    buttonZoom.backgroundColor = [UIColor whiteColor];
    buttonZoom.layer.borderWidth = 1.0;
    buttonZoom.layer.borderColor = [UIColor grayColor].CGColor;
    [buttonZoom addTarget:self action:@selector(buttonZoomTapped:) forControlEvents:UIControlEventTouchUpInside];

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

AVCaptureDevicePosition cameraPosition = AVCaptureDevicePositionBack;

- (void)buttonSwapTapped:(UIButton *)sender {
    if (self.publisher != NULL) {
        if(cameraPosition == AVCaptureDevicePositionBack) {
            [self.publisher setCameraPosition:AVCaptureDevicePositionFront];
        } else {
            [self.publisher setCameraPosition:AVCaptureDevicePositionBack];
        }
        
    }
}

- (void)buttonTorchTapped:(UIButton *)sender {
    publisher.cameraTorch = !publisher.cameraTorch;
    sender.backgroundColor = _publisher.cameraTorch ? [UIColor redColor] : [UIColor greenColor];
}

float zoomFactor = 1.0f;

- (void)buttonZoomTapped:(UIButton *)sender {
    if (zoomFactor == 0.5f) {
        zoomFactor = 1.0f;
    } else if (zoomFactor == 1.0f) {
        zoomFactor = 5.0f;
    } else {
        zoomFactor = 0.5f;
    }

    publisher.setCameraZoomFactor = zoomFactor;
}

@end
