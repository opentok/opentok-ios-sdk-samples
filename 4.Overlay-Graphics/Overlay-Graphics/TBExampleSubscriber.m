//
//  TBSubscriber.m
//  Overlay-Graphics
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#import "TBExampleSubscriber.h"
#import "TBExampleVideoRender.h"

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
    }
    return self;
}

- (void)dealloc {
    [self setVideoRender:nil];
    [_myVideoRender release];
    _myVideoRender = nil;
    [super dealloc];
}

#pragma mark - OTVideoViewDelegate

- (void)videoView:(UIView*)videoView
subscriberVolumeWasMuted:(BOOL)subscriberMuted
{
    [self setSubscribeToAudio:!subscriberMuted];
}

@end
