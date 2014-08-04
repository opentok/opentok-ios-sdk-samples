//
//  TBSubscriber.m
//  Lets-Build-OTPublisher
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "TBExampleSubscriber.h"
#import "TBExampleVideoRender.h"

// Internally forward-declare that we can receive renderer delegate callbacks
@interface TBExampleSubscriber () <TBRendererDelegate>
@end

@implementation TBExampleSubscriber {
    TBExampleVideoView* _myVideoRender;
}

@synthesize view = _myVideoRender;

- (id)initWithStream:(OTStream *)stream
            delegate:(id<OTSubscriberKitDelegate>)delegate
{
    self = [super initWithStream:stream delegate:delegate];
    if (self) {
        _myVideoRender =
        [[TBExampleVideoView alloc] initWithFrame:CGRectMake(0,0,1,1)
                                         delegate:self
                                             type:OTVideoViewTypeSubscriber
                                      displayName:nil];

        [self setVideoRender:_myVideoRender];
        
        // Observe important stream attributes to properly react to changes
        [self.stream addObserver:self
                      forKeyPath:@"hasVideo"
                         options:NSKeyValueObservingOptionNew
                         context:nil];
        [self.stream addObserver:self
                      forKeyPath:@"hasAudio"
                         options:NSKeyValueObservingOptionNew
                         context:nil];
    }
    return self;
}

- (void)dealloc {
    [self.stream removeObserver:self forKeyPath:@"hasVideo" context:nil];
    [self.stream removeObserver:self forKeyPath:@"hasAudio" context:nil];
    [_myVideoRender release];
    [super dealloc];
}

#pragma mark - KVO listeners for UI updates

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    dispatch_async(dispatch_get_main_queue(), ^() {
        if ([@"hasVideo" isEqualToString:keyPath]) {
            // If the video track has gone away, we can clear the screen.
            BOOL value = [[change valueForKey:@"new"] boolValue];
            if (value) {
                [_myVideoRender.videoView setRenderingEnabled:YES];
            } else {
                [_myVideoRender.videoView setRenderingEnabled:NO];
                [_myVideoRender.videoView clearRenderBuffer];
            }
        } else if ([@"hasAudio" isEqualToString:keyPath]) {
            // nop?
        }
    });
}

#pragma mark - Overrides for UI

- (void)setSubscribeToVideo:(BOOL)subscribeToVideo {
    [super setSubscribeToVideo:subscribeToVideo];
    [_myVideoRender.videoView setRenderingEnabled:subscribeToVideo];
    if (!subscribeToVideo) {
        [_myVideoRender.videoView clearRenderBuffer];
    }
}

#pragma mark - OTVideoViewDelegate

- (void)videoView:(UIView*)videoView
subscriberVolumeWasMuted:(BOOL)subscriberMuted
{
    [self setSubscribeToAudio:!subscriberMuted];
}

#pragma mark - TBRendererDelegate

- (void)renderer:(TBExampleVideoRender *)renderer
 didReceiveFrame:(OTVideoFrame *)frame
{
    dispatch_async(dispatch_get_main_queue(), ^() {
        // post a notification to the controller that video has arrived for this
        // subscriber. Useful for transitioning a "loading" UI.
        if ([self.delegate
             respondsToSelector:@selector(subscriberVideoDataReceived:)])
        {
            [self.delegate subscriberVideoDataReceived:self];
        }
    });
}

@end
