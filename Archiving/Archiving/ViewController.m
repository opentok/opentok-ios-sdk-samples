//
//  ViewController.h
//  Getting Started
//
//  Created by Jeff Swartz on 11/19/14.
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.

#import "ViewController.h"
#import <OpenTok/OpenTok.h>
#import "Config.h"

@interface ViewController ()
<OTSessionDelegate, OTSubscriberKitDelegate, OTPublisherDelegate, UITextViewDelegate, UIScrollViewDelegate>
@property (weak, nonatomic) IBOutlet UIView *controlsView;
@property (weak, nonatomic) IBOutlet UIView *videoContainerView;
@property (weak, nonatomic) IBOutlet UIView *subscriberView;
@property (weak, nonatomic) IBOutlet UIView *publisherView;
@property (weak, nonatomic) IBOutlet UIButton *swapCameraBtn;
@property (weak, nonatomic) IBOutlet UIButton *publisherAudioBtn;
@property (weak, nonatomic) IBOutlet UIButton *subscriberAudioBtn;
@property (weak, nonatomic) IBOutlet UIImageView *archiveIndicatorImg;
@property (weak, nonatomic) IBOutlet UIButton *archiveControlBtn;

@end

@implementation ViewController {
    OTSession* _session;
    OTPublisher* _publisher;
    OTSubscriber* _subscriber;
    NSString* _archiveId;
    NSString* _apiKey;
    NSString* _sessionId;
    NSString* _token;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self getSessionCredentials];
}

- (void)getSessionCredentials
{
    NSString* urlPath = SAMPLE_SERVER_BASE_URL;
    urlPath = [urlPath stringByAppendingString:@"/session"];
    NSURL *url = [NSURL URLWithString: urlPath];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    [request setHTTPMethod: @"GET"];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        if (error){
            NSLog(@"Error,%@, URL: %@", [error localizedDescription],urlPath);
        }
        else{
            NSDictionary *roomInfo = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            _apiKey = [roomInfo objectForKey:@"apiKey"];
            _token = [roomInfo objectForKey:@"token"];
            _sessionId = [roomInfo objectForKey:@"sessionId"];
            
            if(!_apiKey || !_token || !_sessionId) {
                NSLog(@"Error invalid response from server, URL: %@",urlPath);
            } else {
                [self doConnect];
            }
        }
    }];
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

- (void)doConnect
{
    // Initialize a new instance of OTSession and begin the connection process.
    _session = [[OTSession alloc] initWithApiKey:_apiKey
                                       sessionId:_sessionId
                                        delegate:self];
    OTError *error = nil;
    [_session connectWithToken:_token error:&error];
    if (error)
    {
        NSLog(@"Unable to connect to session (%@)",
              error.localizedDescription);
    }
}

- (void)doPublish
{
    _publisher = [[OTPublisher alloc]
                  initWithDelegate:self];
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error)
    {
        NSLog(@"Unable to publish (%@)",
              error.localizedDescription);
    }
    
    [_publisher.view setFrame:CGRectMake(0, 0, _publisherView.bounds.size.width,
                                         _publisherView.bounds.size.height)];
    [_publisherView addSubview:_publisher.view];

    
    _publisherAudioBtn.hidden = NO;
    [_publisherAudioBtn addTarget:self
                          action:@selector(togglePublisherMic)
                forControlEvents:UIControlEventTouchUpInside];
    
    _swapCameraBtn.hidden = NO;
    [_swapCameraBtn addTarget:self
               action:@selector(swapCamera)
     forControlEvents:UIControlEventTouchUpInside];

    if (SAMPLE_SERVER_BASE_URL) {
        _archiveControlBtn.hidden = NO;
        [_archiveControlBtn addTarget:self
                               action:@selector(startArchive)
                     forControlEvents:UIControlEventTouchUpInside];
    }
}

-(void)togglePublisherMic
{
    _publisher.publishAudio = !_publisher.publishAudio;
    UIImage *buttonImage;
    if (_publisher.publishAudio) {
        buttonImage = [UIImage imageNamed: @"mic-24.png"];
    } else {
        buttonImage = [UIImage imageNamed: @"mic_muted-24.png"];
    }
    [_publisherAudioBtn setImage:buttonImage forState:UIControlStateNormal];
}

-(void)toggleSubscriberAudio
{
    _subscriber.subscribeToAudio = !_subscriber.subscribeToAudio;
    UIImage *buttonImage;
    if (_subscriber.subscribeToAudio) {
        buttonImage = [UIImage imageNamed: @"Subscriber-Speaker-35.png"];
    } else {
        buttonImage = [UIImage imageNamed: @"Subscriber-Speaker-Mute-35.png"];
    }
    [_subscriberAudioBtn setImage:buttonImage forState:UIControlStateNormal];
}

-(void)swapCamera
{
    if (_publisher.cameraPosition == AVCaptureDevicePositionFront) {
        _publisher.cameraPosition = AVCaptureDevicePositionBack;
    } else {
        _publisher.cameraPosition = AVCaptureDevicePositionFront;
    }
}

- (void)cleanupPublisher {
    [_publisher.view removeFromSuperview];
    _publisher = nil;
}

- (void)doSubscribe:(OTStream*)stream
{
    _subscriber = [[OTSubscriber alloc] initWithStream:stream
                                              delegate:self];
    OTError *error = nil;
    [_session subscribe:_subscriber error:&error];
    if (error)
    {
        NSLog(@"Unable to publish (%@)",
              error.localizedDescription);
    }
}

- (void)cleanupSubscriber
{
    [_subscriber.view removeFromSuperview];
    _subscriber = nil;
}

-(void)startArchive
{
    _archiveControlBtn.hidden = YES;
    NSString *fullURL = SAMPLE_SERVER_BASE_URL;
    fullURL = [fullURL stringByAppendingString:@"/start/"];
    fullURL = [fullURL stringByAppendingString:_sessionId];
    NSURL *url = [NSURL URLWithString: fullURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    [request setHTTPMethod: @"POST"];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        if (error){
            NSLog(@"Error starting the archive: %@. URL : %@",
                  [error localizedDescription],
                  fullURL);
        }
        else{
            NSLog(@"Web service call to start the archive: %@", fullURL);
        }
    }];
}

-(void)stopArchive
{
    _archiveControlBtn.hidden = YES;
    NSString *fullURL = SAMPLE_SERVER_BASE_URL;
    fullURL = [fullURL stringByAppendingString:@"/stop/"];
    fullURL = [fullURL stringByAppendingString:_archiveId];
    NSURL *url = [NSURL URLWithString: fullURL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
    [request setHTTPMethod: @"POST"];
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
        if (error){
            NSLog(@"Error stopping the archive: %@. URL : %@",
                  [error localizedDescription],fullURL);
        }
        else{
            NSLog(@"Web service call to stop the archive: %@", fullURL);
        }
    }];
}

-(void)loadArchivePlaybackInBrowser
{
    NSString *fullURL = SAMPLE_SERVER_BASE_URL;
    fullURL = [fullURL stringByAppendingString:@"/view/"];
    fullURL = [fullURL stringByAppendingString:_archiveId];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:fullURL]];
}

# pragma mark - OTSession delegate callbacks

- (void)sessionDidConnect:(OTSession*)session
{
    [self doPublish];
}

- (void)sessionDidDisconnect:(OTSession*)session
{
    NSString* alertMessage =
    [NSString stringWithFormat:@"Session disconnected: (%@)",
     session.sessionId];
    NSLog(@"sessionDidDisconnect (%@)", alertMessage);
}

- (void)session:(OTSession*)session
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
}

- (void) session:(OTSession*)session
didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
}

- (void)     session:(OTSession*)session
archiveStartedWithId:(NSString *)archiveId
                name:(NSString *)name
{
    NSLog(@"session archiving started with id:%@ name:%@", archiveId, name);
    _archiveId = archiveId;
    _archiveIndicatorImg.hidden = NO;
    if (SAMPLE_SERVER_BASE_URL) {
        _archiveControlBtn.hidden = NO;
        [_archiveControlBtn setTitle: @"Stop recording" forState:UIControlStateNormal];
        _archiveControlBtn.hidden = NO;
        [_archiveControlBtn addTarget:self
                               action:@selector(stopArchive)
                     forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)     session:(OTSession*)session
archiveStoppedWithId:(NSString *)archiveId
{
    NSLog(@"session archiving stopped with id:%@", archiveId);
    _archiveIndicatorImg.hidden = YES;
    if (SAMPLE_SERVER_BASE_URL) {
        _archiveControlBtn.hidden = NO;
        [_archiveControlBtn setTitle: @"View recording" forState:UIControlStateNormal];
        [_archiveControlBtn addTarget:self
                               action:@selector(loadArchivePlaybackInBrowser)
                     forControlEvents:UIControlEventTouchUpInside];
    }
}


# pragma mark - OTPublisher delegate callbacks

- (void)publisher:(OTPublisherKit *)publisher
streamCreated:(OTStream *)stream
{
    NSLog(@"Now publishing.");
}

- (void)publisher:(OTPublisherKit*)publisher
streamDestroyed:(OTStream *)stream
{
    [self cleanupPublisher];
}

- (void)publisher:(OTPublisherKit*)publisher
didFailWithError:(OTError*) error
{
    NSLog(@"publisher didFailWithError %@", error);
    [self cleanupPublisher];
}

# pragma mark - OTSubscriber delegate callbacks

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber
{
    NSLog(@"subscriberDidConnectToStream (%@)",
          subscriber.stream.connection.connectionId);
    [_subscriber.view setFrame:CGRectMake(0, 0, _subscriberView.bounds.size.width,
                                          _subscriberView.bounds.size.height)];
    [_subscriberView addSubview:_subscriber.view];
    
    _subscriberAudioBtn.hidden = NO;
    [_subscriberAudioBtn addTarget:self
                           action:@selector(toggleSubscriberAudio)
                 forControlEvents:UIControlEventTouchUpInside];

}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    NSLog(@"subscriber %@ didFailWithError %@",
          subscriber.stream.streamId,
          error);
}

@end
