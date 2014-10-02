//
//  TBScreenPublisher.m
//  Screen-Sharing
//
//  Copyright (c) 2014 TokBox Inc. All rights reserved.
//

#import "TBScreenPublisher.h"
#import "TBScreenCapture.h"

@interface TBScreenCapture ()
@property (strong) TBScreenCapture* videoCapture;
@end

@implementation TBScreenPublisher
{
    TBScreenCapture *_defaultVideoCapture;
}

@synthesize videoCapture = _defaultVideoCapture;

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

- (id)initWithDelegate:(id<OTPublisherDelegate>)delegate name:(NSString*)name
{
    self = [super initWithDelegate:delegate name:name];
    if (self) {
        [self setVideoRender:nil];
    }
    return self;
}

- (void)dealloc {
    self.videoCapture = nil;
}

#pragma mark - Overrides for public API

- (void)setVideoCapture:(id<OTVideoCapture>)vc {
    [super setVideoCapture:vc];
    _defaultVideoCapture = nil;
    
    // Save the new instance if it's still compatible with the public contract
    // for defaultVideoCapture
    if ([vc isKindOfClass:[TBScreenCapture class]]) {
        _defaultVideoCapture = (TBScreenCapture*) vc;
    }
}

#pragma mark - Overrides for UI

- (void)setPublishVideo:(BOOL)publishVideo {
    [super setPublishVideo:publishVideo];
    if (!publishVideo) {
        
    }
}


@end