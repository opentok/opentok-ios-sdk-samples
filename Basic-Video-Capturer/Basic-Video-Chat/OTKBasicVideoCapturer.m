//
//  OTKBasicVideoCapturer.m
//  Getting Started
//
//  Created by rpc on 03/03/15.
//  Copyright (c) 2015 OpenTok. All rights reserved.
//

#import "OTKBasicVideoCapturer.h"
#define kFramesPerSecond 15
#define kImageWidth 320
#define kImageHeight 240
#define kTimerInterval dispatch_time(DISPATCH_TIME_NOW, (int64_t)((1 / kFramesPerSecond) * NSEC_PER_SEC))

@interface OTKBasicVideoCapturer ()
@property (nonatomic, assign) BOOL captureStarted;
@property (nonatomic, strong) OTVideoFormat *format;
- (void)produceFrame;
@end

@implementation OTKBasicVideoCapturer

@synthesize videoCaptureConsumer;

- (void)initCapture
{
    self.format = [[OTVideoFormat alloc] init];
    self.format.pixelFormat = OTPixelFormatARGB;
    self.format.bytesPerRow = [@[@(kImageWidth * 4)] mutableCopy];
    self.format.imageHeight = kImageHeight;
    self.format.imageWidth = kImageWidth;
}

- (void)releaseCapture
{
    self.format = nil;
}

- (int32_t)startCapture
{
    self.captureStarted = YES;
    dispatch_after(kTimerInterval,
                   dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                   ^{
                       [self produceFrame];
                   });
    
    return 0;
}

- (int32_t)stopCapture
{
    self.captureStarted = NO;
    return 0;
}

- (BOOL)isCaptureStarted
{
    return self.captureStarted;
}

- (int32_t)captureSettings:(OTVideoFormat*)videoFormat
{
    return 0;
}

- (void)produceFrame
{
    OTVideoFrame *frame = [[OTVideoFrame alloc] initWithFormat:self.format];
    
    // Generate a image with random pixels
    u_int8_t *imageData[1];
    imageData[0] = malloc(sizeof(uint8_t) * kImageHeight * kImageWidth * 4);
    for (int i = 0; i < kImageWidth * kImageHeight * 4; i+=4) {
        imageData[0][i] = rand() % 255;   // A
        imageData[0][i+1] = rand() % 255; // R
        imageData[0][i+2] = rand() % 255; // G
        imageData[0][i+3] = rand() % 255; // B
    }
   
    [frame setPlanesWithPointers:imageData numPlanes:1];
    [self.videoCaptureConsumer consumeFrame:frame];
    
    free(imageData[0]);
    
    if (self.captureStarted) {
        dispatch_after(kTimerInterval,
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0),
                       ^{
                           [self produceFrame];
                       });
    }
}

@end
