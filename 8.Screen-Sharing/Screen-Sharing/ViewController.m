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

@interface ViewController () <OTSessionDelegate, OTPublisherDelegate>

@end


@implementation ViewController {
    OTSession* _session;
    OTPublisherKit* _publisher;
    dispatch_queue_t  _queue;
    dispatch_source_t _timer;
}

@synthesize timeDisplay;

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Setup a timer to periodically update the UI. This gives us something
    // dynamic that we can see on the receiver's end to verify everything works.
    _queue = dispatch_queue_create("ticker-timer", 0);
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0),
                              10ull * NSEC_PER_MSEC, 1ull * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(_timer, ^{
        double timestamp = [[NSDate date] timeIntervalSince1970];
        int64_t timeInMilisInt64 = (int64_t)(timestamp*1000);
        
        NSString *mills = [NSString stringWithFormat:@"%lld", timeInMilisInt64];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.timeDisplay setText:mills];
        });
    });
    
    dispatch_resume(_timer);
    
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
    if (UIInterfaceOrientationPortrait == interfaceOrientation) {
        return YES;
    }
    else {
        return NO;
    }
}

#pragma mark - OpenTok methods

- (void)doConnect
{
    OTError *error = nil;
    
    [_session connectWithToken:kToken error:&error];
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
    _publisher =
    [[OTPublisherKit alloc] initWithDelegate:self
                                        name:[UIDevice currentDevice].name
                                  audioTrack:NO
                                  videoTrack:YES];
    
    // Additionally, the publisher video type can be updated to signal to
    // receivers that the video is from a screencast. This value also disables
    // some downsample scaling that is used to adapt to changing network
    // conditions. We will send at a lower framerate to compensate for this.
    [_publisher setVideoType:OTPublisherKitVideoTypeScreen];
    
    // This disables the audio fallback feature when using routed sessions.
    _publisher.audioFallbackEnabled = NO;

    // Finally, wire up the video source.
    TBScreenCapture* videoCapture =
    [[TBScreenCapture alloc] initWithView:self.view];
    [_publisher setVideoCapture:videoCapture];
    
    OTError *error = nil;
    [_session publish:_publisher error:&error];
    if (error) {
        [self showAlert:[error localizedDescription]];
    }
}

- (void)cleanupPublisher {
    _publisher = nil;
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
}

- (void)session:(OTSession*)session streamDestroyed:(OTStream *)stream
{
    NSLog(@"session streamDestroyed (%@)", stream.streamId);
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
}

- (void) session:(OTSession*)session didFailWithError:(OTError*)error
{
    NSLog(@"didFailWithError: (%@)", error);
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

- (void)showAlert:(NSString *)string
{
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
