//
//  TBScreenCapture.m
//  Screen-Sharing
//
//  Copyright (c) 2014 TokBox Inc. All rights reserved.
//

#include <mach/mach.h>
#include <mach/mach_time.h>
#import "TBScreenCapture.h"

@interface TBScreenCapture ()
{
    CMTime _minFrameDuration;
    dispatch_queue_t _queue;
    dispatch_source_t _timer;
}

@property uint32_t captureWidth;
@property uint32_t captureHeight;
@property CVPixelBufferRef pixelBuffer;
@property BOOL capturing;
@property (nonatomic, strong) OTVideoFrame *videoFrame;
@property (nonatomic, strong) UIImage *image;

- (UIImage *)screenshot;

@end

@implementation TBScreenCapture

#pragma mark - Class Lifecycle.

- (instancetype)init
{
    self = [super init];
    if (self) {

        _captureWidth = 480;
        _captureHeight = 640;
        _minFrameDuration = CMTimeMake(1, 7);
        _queue = dispatch_queue_create("CAPTURE QUEUE", NULL);
        
        OTVideoFormat *format = [[OTVideoFormat alloc] init];
        [format setPixelFormat:OTPixelFormatARGB];
        [format setImageWidth:_captureWidth];
        [format setImageHeight:_captureHeight];
        [[format bytesPerRow] addObject:@(_captureWidth * 4)];
        
        _videoFrame = [[OTVideoFrame alloc] initWithFormat:format];
        
        CGSize frameSize = CGSizeMake(_captureWidth, _captureHeight);
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @NO,
                                 kCVPixelBufferCGImageCompatibilityKey,
                                 @NO,
                                 kCVPixelBufferCGBitmapContextCompatibilityKey,
                                 nil];
        
        CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                              frameSize.width,
                                              frameSize.height,
                                              kCVPixelFormatType_32ARGB,
                                              (__bridge CFDictionaryRef)(options),
                                              &_pixelBuffer);
        
        NSParameterAssert(status == kCVReturnSuccess && _pixelBuffer != NULL);
    }
    return self;
}

- (void)dealloc
{
    [self stopCapture];
    CVPixelBufferRelease(_pixelBuffer);
}

#pragma mark - Capture lifecycle

- (void)initCapture { }

- (void)releaseCapture { }

- (int32_t)startCapture
{
    _capturing = YES;
    __unsafe_unretained TBScreenCapture* _self = self;
    _timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
    
    dispatch_source_set_timer(_timer, dispatch_walltime(NULL, 0), 100ull * NSEC_PER_MSEC, 100ull * NSEC_PER_MSEC);
    
    dispatch_source_set_event_handler(_timer, ^{
        @autoreleasepool {
            __block UIImage* screen = [_self screenshot];
            [_self consumeFrame:[screen CGImage]];
        }
    });
    
    dispatch_resume(_timer);
    
    return 0;
}

- (int32_t)stopCapture
{
    self->_capturing = NO;
    
    __unsafe_unretained TBScreenCapture* _self = self;
    dispatch_sync(_queue, ^{
        if (_self->_timer) {
            dispatch_source_cancel(_self->_timer);
        }
        _self->_timer = nil;
    });

    return 0;
}

- (BOOL)isCaptureStarted
{
    return _capturing;
}

#pragma mark - Screen capture implementation

- (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    
    CGSize frameSize = CGSizeMake(_captureWidth, _captureHeight);
    CVPixelBufferLockBaseAddress(_pixelBuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(_pixelBuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameSize.width,
                                                 frameSize.height,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(_pixelBuffer),
                                                 rgbColorSpace,
                                                 kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
    
    
    CGContextDrawImage(context, CGRectMake(0, 0, _captureWidth, _captureHeight), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(_pixelBuffer, 0);
    
    return _pixelBuffer;
}

- (int32_t)captureSettings:(OTVideoFormat*)videoFormat
{
    videoFormat.pixelFormat = OTPixelFormatARGB;
    videoFormat.imageHeight = _captureHeight;
    videoFormat.imageWidth = _captureWidth;
    return 0;
}

- (UIImage *)screenshot
{
    CGSize imageSize = CGSizeZero;
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UIInterfaceOrientationIsPortrait(orientation)) {
        imageSize = [UIScreen mainScreen].bounds.size;
    } else {
        imageSize = CGSizeMake([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
    }
    
    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
    
    if ([self.view respondsToSelector:@selector(drawViewHierarchyInRect:afterScreenUpdates:)]) {
        [self.view drawViewHierarchyInRect:self.view.bounds afterScreenUpdates:NO];
    }
    else {
        [self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (void) consumeFrame:(CGImageRef)frame {

    static mach_timebase_info_data_t time_info;
    uint64_t time_stamp = 0;
    
    if (!(_capturing && _videoCaptureConsumer)) {
        return;
    }
    
    if (time_info.denom == 0) {
        (void) mach_timebase_info(&time_info);
    }
    
    time_stamp = mach_absolute_time();
    time_stamp *= time_info.numer;
    time_stamp /= time_info.denom;
    
    CMTime time = CMTimeMake(time_stamp, 1000);
    CVImageBufferRef ref = [self pixelBufferFromCGImage:frame];
    
    CVPixelBufferLockBaseAddress(ref, 0);
    
    size_t height = CVPixelBufferGetHeight(ref);
    size_t width = CVPixelBufferGetWidth(ref);
    
    _videoFrame.timestamp = time;
    _videoFrame.format.imageWidth = (uint32_t)width;
    _videoFrame.format.imageHeight = (uint32_t)height;
    _videoFrame.format.estimatedFramesPerSecond = _minFrameDuration.timescale / _minFrameDuration.value;
    _videoFrame.format.estimatedCaptureDelay = 100;
    _videoFrame.orientation = OTVideoOrientationUp;
    
    [_videoFrame clearPlanes];
    [_videoFrame.planes addPointer:CVPixelBufferGetBaseAddress(ref)];
    [_videoCaptureConsumer consumeFrame:_videoFrame];
    
    CVPixelBufferUnlockBaseAddress(ref, 0);
}


@end
