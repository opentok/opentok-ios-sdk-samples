//
//  OTKBasicVideoCapturer.m
//  Getting Started
//
//  Created by rpc on 03/03/15.
//  Copyright (c) 2015 OpenTok. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "OTKBasicVideoCapturerCamera.h"

@interface OTKBasicVideoCapturerCamera ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, assign) BOOL captureStarted;
@property (nonatomic, strong) OTVideoFormat *format;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureDeviceInput *inputDevice;
@property (nonatomic, strong) NSString *sessionPreset;
@property (nonatomic, assign) NSUInteger imageWidth;
@property (nonatomic, assign) NSUInteger imageHeight;
@property (nonatomic, assign) NSUInteger desiredFrameRate;
@property (nonatomic, strong) dispatch_queue_t captureQueue;

- (CGSize)sizeFromAVCapturePreset:(NSString *)capturePreset;
- (double)bestFrameRateForDevice;
@end

@implementation OTKBasicVideoCapturerCamera
@synthesize videoCaptureConsumer;

- (id)initWithPreset:(NSString *)preset andDesiredFrameRate:(NSUInteger)frameRate
{
    self = [super init];
    if (self) {
        self.sessionPreset = preset;
        CGSize imageSize = [self sizeFromAVCapturePreset:self.sessionPreset];
        _imageHeight = imageSize.height;
        _imageWidth = imageSize.width;
        _desiredFrameRate = frameRate;
        
        _captureQueue = dispatch_queue_create("com.tokbox.OTKBasicVideoCapturer",DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)initCapture
{
    NSError *error;
    self.captureSession = [[AVCaptureSession alloc] init];
    
    [self.captureSession beginConfiguration];
    
    // Set device capture
    self.captureSession.sessionPreset = self.sessionPreset;
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    self.inputDevice = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    [self.captureSession addInput:self.inputDevice];

     
    AVCaptureVideoDataOutput *outputDevice = [[AVCaptureVideoDataOutput alloc] init];
    outputDevice.alwaysDiscardsLateVideoFrames = YES;
    outputDevice.videoSettings = @{
                                   (NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
                                   };
    
    [outputDevice setSampleBufferDelegate:self queue:self.captureQueue];
    
    [self.captureSession addOutput:outputDevice];
    
    // Set framerate
    double bestFrameRate = [self bestFrameRateForDevice];
    
    CMTime desiredMinFrameDuration = CMTimeMake(1, bestFrameRate);
    CMTime desiredMaxFrameDuration = CMTimeMake(1, bestFrameRate);
    
    [self.inputDevice.device lockForConfiguration:&error];
    self.inputDevice.device.activeVideoMaxFrameDuration = desiredMaxFrameDuration;
    self.inputDevice.device.activeVideoMinFrameDuration = desiredMinFrameDuration;
    
    [self.captureSession commitConfiguration];

    self.format = [OTVideoFormat videoFormatNV12WithWidth:self.imageWidth
                                                   height:self.imageHeight];
}

- (void)releaseCapture
{
    self.format = nil;
}

- (int32_t)startCapture
{
    self.captureStarted = YES;
    [self.captureSession startRunning];
    
    return 0;
}

- (int32_t)stopCapture
{
    self.captureStarted = NO;
    [self.captureSession stopRunning];
    return 0;
}

- (BOOL)isCaptureStarted
{
    return self.captureStarted;
}

- (int32_t)captureSettings:(OTVideoFormat*)videoFormat
{
    videoFormat.pixelFormat = OTPixelFormatNV12;
    videoFormat.imageWidth = self.imageWidth;
    videoFormat.imageHeight = self.imageHeight;
    
    return 0;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"Frame dropped");
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if (!self.captureStarted)
        return;
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    OTVideoFrame *frame = [[OTVideoFrame alloc] initWithFormat:self.format];
    
    NSUInteger planeCount = CVPixelBufferGetPlaneCount(imageBuffer);
    
    uint8_t *buffer = malloc(sizeof(uint8_t) * CVPixelBufferGetDataSize(imageBuffer));
    uint8_t *dst = buffer;
    uint8_t *planes[planeCount];

    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    for (int i = 0; i < planeCount; i++) {
        size_t planeSize = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, i) * CVPixelBufferGetHeightOfPlane(imageBuffer, i);
        
        planes[i] = dst;
        dst += planeSize;
        
        memcpy(planes[i],
                CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i),
                planeSize);
    }
    
    CMTime minFrameDuration = self.inputDevice.device.activeVideoMinFrameDuration;
    frame.format.estimatedFramesPerSecond = minFrameDuration.timescale / minFrameDuration.value;
    frame.format.estimatedCaptureDelay = 100;
    frame.orientation = [self currentDeviceOrientation];
    
    CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    frame.timestamp = time;
    [frame setPlanesWithPointers:planes numPlanes:planeCount];
    
    [self.videoCaptureConsumer consumeFrame:frame];
    
    free(buffer);
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

#pragma mark - Private methods

- (CGSize)sizeFromAVCapturePreset:(NSString *)capturePreset
{
    if ([capturePreset isEqualToString:AVCaptureSessionPreset1280x720])
        return CGSizeMake(1280, 720);
    if ([capturePreset isEqualToString:AVCaptureSessionPreset1920x1080])
        return CGSizeMake(1920, 1080);
    if ([capturePreset isEqualToString:AVCaptureSessionPreset640x480])
        return CGSizeMake(640, 480);
    if ([capturePreset isEqualToString:AVCaptureSessionPreset352x288])
        return CGSizeMake(352, 288);
    
    // Not supported preset
    return CGSizeMake(0, 0);
}

- (OTVideoOrientation)currentDeviceOrientation
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (AVCaptureDevicePositionFront == self.inputDevice.device.position) {
        switch (orientation) {
            case UIInterfaceOrientationLandscapeLeft:
                return OTVideoOrientationUp;
            case UIInterfaceOrientationLandscapeRight:
                return OTVideoOrientationDown;
            case UIInterfaceOrientationPortrait:
                return OTVideoOrientationLeft;
            case UIInterfaceOrientationPortraitUpsideDown:
                return OTVideoOrientationRight;
            default:
                return OTVideoOrientationUp;
        }
    } else {
        switch (orientation) {
            case UIInterfaceOrientationLandscapeLeft:
                return OTVideoOrientationDown;
            case UIInterfaceOrientationLandscapeRight:
                return OTVideoOrientationUp;
            case UIInterfaceOrientationPortrait:
                return OTVideoOrientationLeft;
            case UIInterfaceOrientationPortraitUpsideDown:
                return OTVideoOrientationRight;
            default:
                return OTVideoOrientationUp;
        }
    }
}

- (double)bestFrameRateForDevice
{
    double bestFrameRate = 0;
    for (AVFrameRateRange* range in
         self.inputDevice.device.activeFormat.videoSupportedFrameRateRanges)
    {
        CMTime currentDuration = range.minFrameDuration;
        double currentFrameRate = currentDuration.timescale / currentDuration.value;
        if (currentFrameRate > bestFrameRate && currentFrameRate < self.desiredFrameRate) {
            bestFrameRate = currentFrameRate;
        }
    }
    return bestFrameRate;
}

@end
