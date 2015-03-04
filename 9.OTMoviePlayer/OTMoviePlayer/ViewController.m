//
//  ViewController.m
//  OTMoviePlayer
//
//  Copyright (c) 2015 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import "OTMoviePlayer.h"
#import <MediaPlayer/MediaPlayer.h>
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>

@interface ViewController () <OTSessionDelegate, OTPublisherDelegate, OTSubscriberKitDelegate>
@end

static NSString* kApiKey = @"";
static NSString* kSessionId = @"";
static NSString* kToken = @"";

static bool doPublish = YES;
static bool doSubscribe = NO;
static bool doSubscribeToSelf = NO;
static OTMoviePlayer* moviePlayer = nil;

@implementation ViewController {
    OTSession* mySession;
    OTPublisher* myPublisher;
    OTSubscriber* mySubscriber;
}

- (void) startMovie:(NSURL*) movieUrl
{
    moviePlayer = [[OTMoviePlayer alloc] init];
    moviePlayer.loop = YES;
    [moviePlayer loadMovieAssets:movieUrl];
    
    [OTAudioDeviceManager setAudioDevice:moviePlayer.audioDevice];
    
    mySession = [[OTSession alloc] initWithApiKey:kApiKey
                                        sessionId:kSessionId
                                         delegate:self];
    [mySession connectWithToken:kToken error:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

}

- (void) viewDidAppear:(BOOL)animated
{
    NSURL *movieUrl=[[NSBundle mainBundle]
                     URLForResource:@"OpenTok" withExtension:@"mp4"];

    [self startMovie:movieUrl];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)subscribeToStream:(OTStream*)stream {
    if (doSubscribe && nil == mySubscriber) {
        mySubscriber = [[OTSubscriber alloc] initWithStream:stream
                                                   delegate:self];
        [mySession subscribe:mySubscriber error:nil];
        
        [mySubscriber.view setFrame:CGRectMake(0, 240, 320, 240)];
        [[self view] addSubview:mySubscriber.view];
    }
}

- (void)sessionDidConnect:(OTSession*)session {
    
    if (doPublish) {
        myPublisher = [[OTPublisher alloc] initWithDelegate:self];
        //myPublisher.cameraPosition = AVCaptureDevicePositionBack;
        myPublisher.videoCapture = moviePlayer.videoCapture;
        [myPublisher.view setFrame:CGRectMake(0, 0, 320, 240)];
        [[self view] addSubview:myPublisher.view];
        [mySession publish:myPublisher error:nil];
    }
    [self.view setBackgroundColor:[UIColor greenColor]];

}

- (void)sessionDidDisconnect:(OTSession*)session {
    [self.view setBackgroundColor:[UIColor grayColor]];
}

- (void)session:(OTSession*)session didFailWithError:(OTError*)error {
    [self.view setBackgroundColor:[UIColor redColor]];

}

- (void)session:(OTSession*)session streamCreated:(OTStream*)stream {
    if (!doSubscribeToSelf) {
        [self subscribeToStream:stream];
    }
}

- (void)session:(OTSession*)session streamDestroyed:(OTStream*)stream {
    if ([mySubscriber.stream.streamId isEqualToString:stream.streamId]) {
        [mySubscriber.view removeFromSuperview];
        [mySubscriber release];
        mySubscriber = nil;
    }
}

- (void)   session:(OTSession*)session
receivedSignalType:(NSString*)type
    fromConnection:(OTConnection*)connection
        withString:(NSString*)string
{
    
}

- (void) session:(OTSession*) session connectionCreated:(OTConnection*) connection { }

- (void) session:(OTSession*)session connectionDestroyed:(OTConnection*) connection { }

- (void)publisher:(OTPublisherKit *)publisher streamCreated:(OTStream *)stream
{
    if (doSubscribeToSelf) {
        [self subscribeToStream:stream];
    }
}

- (void)publisher:(OTPublisherKit *)publisher streamDestroyed:(OTStream *)stream
{
    if ([mySubscriber.stream.streamId isEqualToString:stream.streamId]) {
        [mySubscriber.view removeFromSuperview];
        [mySubscriber release];
        mySubscriber = nil;
    }
}

- (void)publisher:(OTPublisherKit*)publisher didFailWithError:(OTError*)error {
    NSLog(@"publisher error!");
}

- (void)subscriberDidConnectToStream:(OTSubscriberKit*)subscriber {
    [subscriber.stream addObserver:self
                        forKeyPath:@"videoDimensions"
                           options:NSKeyValueObservingOptionNew
                           context:NULL];
    [subscriber.stream addObserver:self
                        forKeyPath:@"hasVideo"
                           options:NSKeyValueObservingOptionNew
                           context:NULL];
    [subscriber.stream addObserver:self
                        forKeyPath:@"hasAudio"
                           options:NSKeyValueObservingOptionNew
                           context:NULL];
    
}

- (void)subscriber:(OTSubscriberKit*)subscriber
  didFailWithError:(OTError*)error
{
    
}

- (void)subscriberVideoDataReceived:(OTSubscriberKit *)subscriber {
    
}


- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    NSLog(@"ViewController: observeValueForKeyPath %@ ofObject %@"
          " change %@ context %p",
          keyPath, [object description], change, context);
    if ([@"videoDimensions" isEqualToString:keyPath]) {

    } else if ([@"hasVideo" isEqualToString:keyPath]) {
        BOOL value = [[change valueForKey:@"new"] boolValue];
        [mySubscriber setSubscribeToVideo:value];
    }
    
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}


- (BOOL)shouldAutorotate {
    return YES;
}

@end
