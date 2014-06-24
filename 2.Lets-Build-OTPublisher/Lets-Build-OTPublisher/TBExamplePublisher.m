//
//  TBExamplePublisher.m
//  Lets-Build-OTPublisher
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "TBExamplePublisher.h"
#import "TBExampleVideoCapture.h"
#import "TBExampleVideoRender.h"

@implementation TBExamplePublisher {
    TBExampleVideoRender* _videoView;
    TBExampleVideoCapture* _defaultVideoCapture;
}

@synthesize view = _videoView;

#pragma mark - Object Lifecycle

- (id)init {
    self = [self initWithDelegate:nil name:nil];
    if (self) {
        // nothing to do!
    }
    return self;
}
- (id)initWithDelegate:(id<OTPublisherDelegate>)delegate {
    self = [self initWithDelegate:delegate name:nil];
    if (self) {
        // nothing to do!
    }
    return self;
}

- (id)initWithDelegate:(id<OTPublisherDelegate>)delegate
                  name:(NSString*)name
{
    self = [super initWithDelegate:delegate name:name];
    if (self) {
        TBExampleVideoCapture* videoCapture =
        [[[TBExampleVideoCapture alloc] init] autorelease];
        [self setVideoCapture:videoCapture];
        
        _videoView =
        [[TBExampleVideoRender alloc] initWithFrame:CGRectMake(0, 0, 1, 1)];
        // Set mirroring only if the front camera is being used.
        [_videoView setMirroring:
         (AVCaptureDevicePositionFront == videoCapture.cameraPosition)];
        [self setVideoRender:_videoView];
    }
    return self;
}

- (void)dealloc {
    [_videoView release];
    _videoView = nil;
    [_defaultVideoCapture removeObserver:self
                              forKeyPath:@"cameraPosition"
                                 context:nil];
    [_defaultVideoCapture release];
    _defaultVideoCapture = nil;
    [super dealloc];
}

#pragma mark - Public API

- (void)setCameraPosition:(AVCaptureDevicePosition)cameraPosition {
    [_defaultVideoCapture setCameraPosition:cameraPosition];
}

- (AVCaptureDevicePosition)cameraPosition {
    return [_defaultVideoCapture cameraPosition];
}

#pragma mark - Overrides for public API

- (void)setVideoCapture:(id<OTVideoCapture>)videoCapture {
    [super setVideoCapture:videoCapture];
    [_defaultVideoCapture removeObserver:self
                              forKeyPath:@"cameraPosition"
                                 context:nil];
    [_defaultVideoCapture release];
    _defaultVideoCapture = nil;
    
    // Save the new instance if it's still compatible with the public contract
    // for defaultVideoCapture
    if ([videoCapture isKindOfClass:[TBExampleVideoCapture class]]) {
        _defaultVideoCapture = (TBExampleVideoCapture*) videoCapture;
        [_defaultVideoCapture retain];
    }
    
    [_defaultVideoCapture addObserver:self
                           forKeyPath:@"cameraPosition"
                              options:NSKeyValueObservingOptionNew
                              context:nil];
    
}

#pragma mark - Overrides for UI

- (void)setPublishVideo:(BOOL)publishVideo {
    [super setPublishVideo:publishVideo];
    if (!publishVideo) {
        [_videoView clearRenderBuffer];
    }
}

#pragma mark - KVO listeners for Delegate notification

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([@"cameraPosition" isEqualToString:keyPath]) {
        // For example, this is how you could notify a delegate about camera
        // position changes.
    }
}

@end