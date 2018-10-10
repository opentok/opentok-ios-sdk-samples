//
//  TBExampleVideoCapture.m
//  otkit-objc-libs
//
//  Created by Charley Robinson on 10/11/13.
//
//

#import <Availability.h>
#import <UIKit/UIKit.h>
#import <OpenTok/OpenTok.h>
#import <CoreVideo/CoreVideo.h>
#import "TBExampleVideoCapture.h"

#define SYSTEM_VERSION_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

@class OTDeviceInfo;
#define RUNTIME_IPHONE_4S [@"iPhone4,1" isEqualToString:[[OTDeviceInfo class] performSelector:@selector(machineName)]]


@implementation TBExampleVideoCapture {
    id<OTVideoCaptureConsumer> _videoCaptureConsumer;
    OTVideoFrame* _videoFrame;
    
    uint32_t _captureWidth;
    uint32_t _captureHeight;
    NSString* _capturePreset;
    
    AVCaptureSession *_captureSession;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;
    
    BOOL _capturing;
    
    dispatch_source_t _blackFrameTimer;
    uint8_t* _blackFrame;
    double _blackFrameTimeStarted;
}

@synthesize captureSession = _captureSession;
@synthesize videoInput = _videoInput, videoOutput = _videoOutput;
@synthesize videoCaptureConsumer = _videoCaptureConsumer;

#define OTK_VIDEO_CAPTURE_IOS_DEFAULT_INITIAL_FRAMERATE 20

-(id)init {
    self = [super init];
    if (self) {
        if (RUNTIME_IPHONE_4S) {
            _capturePreset = AVCaptureSessionPresetMedium;
        } else {
            _capturePreset = AVCaptureSessionPreset640x480;
        }
        [[self class] dimensionsForCapturePreset:_capturePreset
                                           width:&_captureWidth
                                          height:&_captureHeight];
        _capture_queue = dispatch_queue_create("com.tokbox.OTVideoCapture",
                                               DISPATCH_QUEUE_SERIAL);
        _videoFrame = [[OTVideoFrame alloc] initWithFormat:
                       [OTVideoFormat videoFormatNV12WithWidth:_captureWidth
                                                        height:_captureHeight]];
    }
    return self;
}

- (int32_t)captureSettings:(OTVideoFormat*)videoFormat {
    videoFormat.pixelFormat = OTPixelFormatNV12;
    videoFormat.imageWidth = _captureWidth;
    videoFormat.imageHeight = _captureHeight;
    return 0;
}

- (void)dealloc {
    [self stopCapture];
    [self releaseCapture];
    
    if (_capture_queue) {
        dispatch_release(_capture_queue);
        _capture_queue = nil;
    }
    
    [_videoFrame release];
    
    [super dealloc];
}

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *) frontFacingCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

- (AVCaptureDevice *) backFacingCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

- (BOOL) hasMultipleCameras {
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1;
}

- (BOOL) hasTorch {
    return [[[self videoInput] device] hasTorch];
}

- (AVCaptureTorchMode) torchMode {
    return [[[self videoInput] device] torchMode];
}

- (void) setTorchMode:(AVCaptureTorchMode) torchMode {
    
    AVCaptureDevice *device = [[self videoInput] device];
    if ([device isTorchModeSupported:torchMode] &&
        [device torchMode] != torchMode)
    {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setTorchMode:torchMode];
            [device unlockForConfiguration];
        } else {
            //Handle Error
        }
    }
}

- (double) maxSupportedFrameRate {
    AVFrameRateRange* firstRange =
    [_videoInput.device.activeFormat.videoSupportedFrameRateRanges
     objectAtIndex:0];
    
    CMTime bestDuration = firstRange.minFrameDuration;
    double bestFrameRate = bestDuration.timescale / bestDuration.value;
    CMTime currentDuration;
    double currentFrameRate;
    for (AVFrameRateRange* range in
         _videoInput.device.activeFormat.videoSupportedFrameRateRanges)
    {
        currentDuration = range.minFrameDuration;
        currentFrameRate = currentDuration.timescale / currentDuration.value;
        if (currentFrameRate > bestFrameRate) {
            bestFrameRate = currentFrameRate;
        }
    }
    
    return bestFrameRate;
}

- (BOOL)isAvailableActiveFrameRate:(double)frameRate
{
    return (nil != [self frameRateRangeForFrameRate:frameRate]);
}

- (double) activeFrameRate {
    CMTime minFrameDuration = _videoInput.device.activeVideoMinFrameDuration;
    double framesPerSecond =
    minFrameDuration.timescale / minFrameDuration.value;
    
    return framesPerSecond;
}

- (AVFrameRateRange*)frameRateRangeForFrameRate:(double)frameRate {
    for (AVFrameRateRange* range in
         _videoInput.device.activeFormat.videoSupportedFrameRateRanges)
    {
        if (range.minFrameRate <= frameRate && frameRate <= range.maxFrameRate)
        {
            return range;
        }
    }
    return nil;
}

// Yes this "lockConfiguration" is somewhat silly but we're now setting
// the frame rate in initCapture *before* startRunning is called to
// avoid contention, and we already have a config lock at that point.
- (void)setActiveFrameRateImpl:(double)frameRate : (BOOL) lockConfiguration {
    
    if (!_videoOutput || !_videoInput) {
        return;
    }
    
    AVFrameRateRange* frameRateRange =
    [self frameRateRangeForFrameRate:frameRate];
    if (nil == frameRateRange) {
        NSLog(@"unsupported frameRate %f", frameRate);
        return;
    }
    CMTime desiredMinFrameDuration = CMTimeMake(1, frameRate);
    CMTime desiredMaxFrameDuration = CMTimeMake(1, frameRate); // iOS 8 fix
    /*frameRateRange.maxFrameDuration*/;
    
    if(lockConfiguration) [_captureSession beginConfiguration];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        NSError* error;
        if ([_videoInput.device lockForConfiguration:&error]) {
            [_videoInput.device
             setActiveVideoMinFrameDuration:desiredMinFrameDuration];
            [_videoInput.device
             setActiveVideoMaxFrameDuration:desiredMaxFrameDuration];
            [_videoInput.device unlockForConfiguration];
        } else {
            NSLog(@"%@", error);
        }
    } else {
        AVCaptureConnection *conn =
        [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
        if (conn.supportsVideoMinFrameDuration)
            conn.videoMinFrameDuration = desiredMinFrameDuration;
        if (conn.supportsVideoMaxFrameDuration)
            conn.videoMaxFrameDuration = desiredMaxFrameDuration;
    }
    if(lockConfiguration) [_captureSession commitConfiguration];
}

- (void)setActiveFrameRate:(double)frameRate {
    dispatch_sync(_capture_queue, ^{
        return [self setActiveFrameRateImpl : frameRate : TRUE];
    });
}

+ (void)dimensionsForCapturePreset:(NSString*)preset
                             width:(uint32_t*)width
                            height:(uint32_t*)height
{
    if ([preset isEqualToString:AVCaptureSessionPreset352x288]) {
        *width = 352;
        *height = 288;
    } else if ([preset isEqualToString:AVCaptureSessionPreset640x480]) {
        *width = 640;
        *height = 480;
    } else if ([preset isEqualToString:AVCaptureSessionPreset1280x720]) {
        *width = 1280;
        *height = 720;
    } else if ([preset isEqualToString:AVCaptureSessionPreset1920x1080]) {
        *width = 1920;
        *height = 1080;
    } else if ([preset isEqualToString:AVCaptureSessionPresetPhoto]) {
        // see AVCaptureSessionPresetLow
        *width = 1920;
        *height = 1080;
    } else if ([preset isEqualToString:AVCaptureSessionPresetHigh]) {
        // see AVCaptureSessionPresetLow
        *width = 640;
        *height = 480;
    } else if ([preset isEqualToString:AVCaptureSessionPresetMedium]) {
        // see AVCaptureSessionPresetLow
        *width = 480;
        *height = 360;
    } else if ([preset isEqualToString:AVCaptureSessionPresetLow]) {
        // WARNING: This is a guess. might be wrong for certain devices.
        // We'll use updeateCaptureFormatWithWidth:height if actual output
        // differs from expected value
        *width = 192;
        *height = 144;
    }
}

+ (NSSet *)keyPathsForValuesAffectingAvailableCaptureSessionPresets
{
    return [NSSet setWithObjects:@"captureSession", @"videoInput", nil];
}

- (NSArray *)availableCaptureSessionPresets
{
    NSArray *allSessionPresets = [NSArray arrayWithObjects:
                                  AVCaptureSessionPreset352x288,
                                  AVCaptureSessionPreset640x480,
                                  AVCaptureSessionPreset1280x720,
                                  AVCaptureSessionPreset1920x1080,
                                  AVCaptureSessionPresetPhoto,
                                  AVCaptureSessionPresetHigh,
                                  AVCaptureSessionPresetMedium,
                                  AVCaptureSessionPresetLow,
                                  nil];
    
    NSMutableArray *availableSessionPresets =
    [NSMutableArray arrayWithCapacity:9];
    for (NSString *sessionPreset in allSessionPresets) {
        if ([[self captureSession] canSetSessionPreset:sessionPreset])
            [availableSessionPresets addObject:sessionPreset];
    }
    
    return availableSessionPresets;
}

- (void)updateCaptureFormatWithWidth:(uint32_t)width height:(uint32_t)height
{
    _captureWidth = width;
    _captureHeight = height;
    [_videoFrame setFormat:[OTVideoFormat
                            videoFormatNV12WithWidth:_captureWidth
                            height:_captureHeight]];
    
}

- (NSString*)captureSessionPreset {
    return _captureSession.sessionPreset;
}

- (void) setCaptureSessionPreset:(NSString*)preset {
    dispatch_sync(_capture_queue, ^{
        AVCaptureSession *session = [self captureSession];
        
        if ([session canSetSessionPreset:preset] &&
            ![preset isEqualToString:session.sessionPreset]) {
            
            [_captureSession beginConfiguration];
            _captureSession.sessionPreset = preset;
            _capturePreset = preset;
            
            [_videoOutput setVideoSettings:
             [NSDictionary dictionaryWithObjectsAndKeys:
              [NSNumber numberWithInt:
               kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
              kCVPixelBufferPixelFormatTypeKey,
              nil]];
            
            [_captureSession commitConfiguration];
        }
    });
}

- (BOOL) toggleCameraPosition {
    AVCaptureDevicePosition currentPosition = _videoInput.device.position;
    if (AVCaptureDevicePositionBack == currentPosition) {
        [self setCameraPosition:AVCaptureDevicePositionFront];
    } else if (AVCaptureDevicePositionFront == currentPosition) {
        [self setCameraPosition:AVCaptureDevicePositionBack];
    }
    
    // TODO: check for success
    return YES;
}

- (NSArray*)availableCameraPositions {
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    NSMutableSet* result = [NSMutableSet setWithCapacity:devices.count];
    for (AVCaptureDevice* device in devices) {
        [result addObject:[NSNumber numberWithInt:device.position]];
    }
    return [result allObjects];
}

- (AVCaptureDevicePosition)cameraPosition {
    return _videoInput.device.position;
}

- (void)setCameraPosition:(AVCaptureDevicePosition) position {
    __block BOOL success = NO;
    
    NSString* preset = self.captureSession.sessionPreset;
    
    if (![self hasMultipleCameras]) {
        return;
    }
    
    NSError *error;
    AVCaptureDeviceInput *newVideoInput;
    
    if (position == AVCaptureDevicePositionBack) {
        newVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:
                         [self backFacingCamera] error:&error];
        [self setTorchMode:AVCaptureTorchModeOff];
        _videoOutput.alwaysDiscardsLateVideoFrames = YES;
    } else if (position == AVCaptureDevicePositionFront) {
        newVideoInput = [AVCaptureDeviceInput deviceInputWithDevice:
                         [self frontFacingCamera] error:&error];
        _videoOutput.alwaysDiscardsLateVideoFrames = YES;
    } else {
        return;
    }
    
    dispatch_sync(_capture_queue, ^() {
        AVCaptureSession *session = [self captureSession];
        [session beginConfiguration];
        [session removeInput:_videoInput];
        if ([session canAddInput:newVideoInput]) {
            [session addInput:newVideoInput];
            [_videoInput release];
            _videoInput = [newVideoInput retain];
            success = YES;
        } else {
            success = NO;
            [session addInput:_videoInput];
        }
        [session commitConfiguration];
    });
    
    if (success) {
        [self setCaptureSessionPreset:preset];
    }
    return;
}

- (void)releaseCapture {
    [self stopCapture];
    [_videoOutput setSampleBufferDelegate:nil queue:NULL];
    dispatch_sync(_capture_queue, ^() {
        [_captureSession stopRunning];
    });
    [_captureSession release];
    _captureSession = nil;
    [_videoOutput release];
    _videoOutput = nil;
    
    [_videoInput release];
    _videoInput = nil;
    
    if (_blackFrameTimer) {
        dispatch_release(_blackFrameTimer);
        _blackFrameTimer = nil;
    }
    
    free(_blackFrame);
    
}

- (void)setupAudioVideoSession {
    //-- Setup Capture Session.
    
    _captureSession = [[AVCaptureSession alloc] init];
    [_captureSession beginConfiguration];
    
    [_captureSession setSessionPreset:_capturePreset];
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        //Needs to be set in order to receive audio route/interruption events.
        _captureSession.usesApplicationAudioSession = NO;
    }
    
    //-- Create a video device and input from that Device.
    // Add the input to the capture session.
    AVCaptureDevice * videoDevice = [self frontFacingCamera];
    if(videoDevice == nil) {
        NSLog(@"ERROR[OpenTok]: Failed to acquire camera device for video "
              "capture.");
        return;
    }
    
    //-- Add the device to the session.
    NSError *error;
    _videoInput = [[AVCaptureDeviceInput deviceInputWithDevice:videoDevice
                                                         error:&error] retain];
    
    if (AVErrorApplicationIsNotAuthorizedToUseDevice == error.code) {
        [self initBlackFrameSender];
        [_captureSession release];
        _captureSession = nil;
        return;
    }
    
    if(error || _videoInput == nil) {
        NSLog(@"ERROR[OpenTok]: Failed to initialize default video caputre "
              "session. (error=%@)", error);
        return;
    }
    
    [_captureSession addInput:_videoInput];
    
    //-- Create the output for the capture session.
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    [_videoOutput setVideoSettings:
     [NSDictionary dictionaryWithObject:
      [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
                                 forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    [_videoOutput setSampleBufferDelegate:self queue:_capture_queue];
    
    [_captureSession addOutput:_videoOutput];
    
    [self setActiveFrameRateImpl
     : OTK_VIDEO_CAPTURE_IOS_DEFAULT_INITIAL_FRAMERATE : FALSE];
    
    [_captureSession commitConfiguration];
    
    // Fix for 10 seconds delay occuring with new resolution and fps
    // constructor as well as if you set cameraPosition right after regular init
    // OPENTOK-27013, OPENTOK-26905
    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW,
                                          0.1 * NSEC_PER_SEC);
    dispatch_after(delay,_capture_queue,^{
        [_captureSession startRunning];
    });

}

- (void)initCapture {
    dispatch_sync(_capture_queue, ^{
        [self setupAudioVideoSession];
    });
}

- (void)initBlackFrameSender {
    _blackFrameTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,
                                              0, 0, _capture_queue);
    int blackFrameWidth = 320;
    int blackFrameHeight = 240;
    [self updateCaptureFormatWithWidth:blackFrameWidth height:blackFrameHeight];
    
    _blackFrame = malloc(blackFrameWidth * blackFrameHeight * 3 / 2);
    _blackFrameTimeStarted = CACurrentMediaTime();
    
    uint8_t* yPlane = _blackFrame;
    uint8_t* uvPlane =
    &(_blackFrame[(blackFrameHeight * blackFrameWidth)]);
    
    memset(yPlane, 0x00, blackFrameWidth * blackFrameHeight);
    memset(uvPlane, 0x7F, blackFrameWidth * blackFrameHeight / 2);
    
    if (_blackFrameTimer)
    {
        dispatch_source_set_timer(_blackFrameTimer, dispatch_walltime(NULL, 0),
                                  250ull * NSEC_PER_MSEC,
                                  1ull * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(_blackFrameTimer, ^{
            if (!_capturing) {
                return;
            }
            
            double now = CACurrentMediaTime();
            _videoFrame.timestamp =
            CMTimeMake((now - _blackFrameTimeStarted) * 90000, 90000);
            _videoFrame.format.imageWidth = blackFrameWidth;
            _videoFrame.format.imageHeight = blackFrameHeight;
            
            _videoFrame.format.estimatedFramesPerSecond = 4;
            _videoFrame.format.estimatedCaptureDelay = 0;
            _videoFrame.orientation = OTVideoOrientationUp;
            
            [_videoFrame clearPlanes];
            
            [_videoFrame.planes addPointer:yPlane];
            [_videoFrame.planes addPointer:uvPlane];
            
            [_videoCaptureConsumer consumeFrame:_videoFrame];
        });
        
        dispatch_resume(_blackFrameTimer);
    }
    
}

- (BOOL) isCaptureStarted {
    return (_captureSession || _blackFrameTimer) && _capturing;
}

- (int32_t) startCapture {
    _capturing = YES;
    return 0;
}

- (int32_t) stopCapture {
    _capturing = NO;
    return 0;
}

- (void)currentDeviceOrientation: (void (^)(OTVideoOrientation result))callback
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        // transforms are different for
        if (AVCaptureDevicePositionFront == self.cameraPosition)
        {
            switch (orientation) {
                case UIInterfaceOrientationLandscapeLeft:
                    callback(OTVideoOrientationUp);
                case UIInterfaceOrientationLandscapeRight:
                    callback(OTVideoOrientationDown);
                case UIInterfaceOrientationPortrait:
                    callback(OTVideoOrientationLeft);
                case UIInterfaceOrientationPortraitUpsideDown:
                    callback(OTVideoOrientationRight);
                case UIInterfaceOrientationUnknown:
                    callback(OTVideoOrientationUp);
            }
        }
        else
        {
            switch (orientation) {
                case UIInterfaceOrientationLandscapeLeft:
                    callback(OTVideoOrientationDown);
                case UIInterfaceOrientationLandscapeRight:
                    callback(OTVideoOrientationUp);
                case UIInterfaceOrientationPortrait:
                    callback(OTVideoOrientationLeft);
                case UIInterfaceOrientationPortraitUpsideDown:
                    callback(OTVideoOrientationRight);
                case UIInterfaceOrientationUnknown:
                    callback(OTVideoOrientationUp);
            }
        }
        callback(OTVideoOrientationUp);
        
    });
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    
}

/**
 * Def: sanitary(n): A contiguous image buffer with no padding. All bytes in the
 * store are actual pixel data.
 */
- (BOOL)imageBufferIsSanitary:(CVImageBufferRef)imageBuffer
{
    size_t planeCount = CVPixelBufferGetPlaneCount(imageBuffer);
    // (Apple bug?) interleaved chroma plane measures in at half of actual size.
    // No idea how many pixel formats this applys to, but we're specifically
    // targeting 4:2:0 here, so there are some assuptions that must be made.
    BOOL biplanar = (2 == planeCount);
    
    for (int i = 0; i < CVPixelBufferGetPlaneCount(imageBuffer); i++) {
        size_t imageWidth =
        CVPixelBufferGetWidthOfPlane(imageBuffer, i) *
        CVPixelBufferGetHeightOfPlane(imageBuffer, i);
        
        if (biplanar && 1 == i) {
            imageWidth *= 2;
        }
        
        size_t dataWidth =
        CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, i) *
        CVPixelBufferGetHeightOfPlane(imageBuffer, i);
        
        if (imageWidth != dataWidth) {
            return NO;
        }
        
        BOOL hasNextAddress = CVPixelBufferGetPlaneCount(imageBuffer) > i + 1;
        BOOL nextPlaneContiguous = YES;
        
        if (hasNextAddress) {
            size_t planeLength =
            dataWidth;
            
            uint8_t* baseAddress =
            CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i);
            
            uint8_t* nextAddress =
            CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i + 1);
            
            nextPlaneContiguous = &(baseAddress[planeLength]) == nextAddress;
        }
        
        if (!nextPlaneContiguous) {
            return NO;
        }
    }
    
    return YES;
}
- (size_t)sanitizeImageBuffer:(CVImageBufferRef)imageBuffer
                         data:(uint8_t**)data
                       planes:(NSPointerArray*)planes
{
    uint32_t pixelFormat = CVPixelBufferGetPixelFormatType(imageBuffer);
    if (kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange == pixelFormat ||
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange == pixelFormat)
    {
        return [self sanitizeBiPlanarImageBuffer:imageBuffer
                                            data:data
                                          planes:planes];
    } else {
        NSLog(@"No sanitization implementation for pixelFormat %d",
              pixelFormat);
        *data = NULL;
        return 0;
    }
}

- (size_t)sanitizeBiPlanarImageBuffer:(CVImageBufferRef)imageBuffer
                                 data:(uint8_t**)data
                               planes:(NSPointerArray*)planes
{
    size_t sanitaryBufferSize = 0;
    for (int i = 0; i < CVPixelBufferGetPlaneCount(imageBuffer); i++) {
        size_t planeImageWidth =
        // TODO: (Apple bug?) biplanar pixel format reports 1/2 the width of
        // what actually ends up in the pixel buffer for interleaved chroma.
        // The only thing I could do about it is use image width for both plane
        // calculations, in spite of this being technically wrong.
        //CVPixelBufferGetWidthOfPlane(imageBuffer, i);
        CVPixelBufferGetWidth(imageBuffer);
        size_t planeImageHeight =
        CVPixelBufferGetHeightOfPlane(imageBuffer, i);
        sanitaryBufferSize += (planeImageWidth * planeImageHeight);
    }
    uint8_t* newImageBuffer = malloc(sanitaryBufferSize);
    size_t bytesCopied = 0;
    for (int i = 0; i < CVPixelBufferGetPlaneCount(imageBuffer); i++) {
        [planes addPointer:&(newImageBuffer[bytesCopied])];
        void* planeBaseAddress =
        CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i);
        size_t planeDataWidth =
        CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, i);
        size_t planeImageWidth =
        // Same as above. Use full image width for both luma and interleaved
        // chroma planes.
        //CVPixelBufferGetWidthOfPlane(imageBuffer, i);
        CVPixelBufferGetWidth(imageBuffer);
        size_t planeImageHeight =
        CVPixelBufferGetHeightOfPlane(imageBuffer, i);
        for (int rowIndex = 0; rowIndex < planeImageHeight; rowIndex++) {
            memcpy(&(newImageBuffer[bytesCopied]),
                   &(planeBaseAddress[planeDataWidth * rowIndex]),
                   planeImageWidth);
            bytesCopied += planeImageWidth;
        }
    }
    assert(bytesCopied == sanitaryBufferSize);
    *data = newImageBuffer;
    return bytesCopied;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    if (!(_capturing && _videoCaptureConsumer)) {
        return;
    }
    
    CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    _videoFrame.timestamp = time;
    uint32_t height = (uint32_t)CVPixelBufferGetHeight(imageBuffer);
    uint32_t width = (uint32_t)CVPixelBufferGetWidth(imageBuffer);
    if (width != _captureWidth || height != _captureHeight) {
        [self updateCaptureFormatWithWidth:width height:height];
    }
    _videoFrame.format.imageWidth = width;
    _videoFrame.format.imageHeight = height;
    CMTime minFrameDuration;
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        minFrameDuration = _videoInput.device.activeVideoMinFrameDuration;
    } else {
        AVCaptureConnection *conn =
        [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
        minFrameDuration = conn.videoMinFrameDuration;
    }
    _videoFrame.format.estimatedFramesPerSecond =
    minFrameDuration.timescale / minFrameDuration.value;
    // TODO: how do we measure this from AVFoundation?
    _videoFrame.format.estimatedCaptureDelay = 100;
    [self currentDeviceOrientation: ^(OTVideoOrientation result) {
         _videoFrame.orientation = result;
    }];
    
    [_videoFrame clearPlanes];
    uint8_t* sanitizedImageBuffer = NULL;
    
    if (!CVPixelBufferIsPlanar(imageBuffer))
    {
        [_videoFrame.planes
         addPointer:CVPixelBufferGetBaseAddress(imageBuffer)];
    } else if ([self imageBufferIsSanitary:imageBuffer]) {
        for (int i = 0; i < CVPixelBufferGetPlaneCount(imageBuffer); i++) {
            [_videoFrame.planes addPointer:
             CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i)];
        }
    } else {
        [self sanitizeImageBuffer:imageBuffer
                             data:&sanitizedImageBuffer
                           planes:_videoFrame.planes];
    }
    
    if (self.delegate) {
        [self.delegate finishPreparingFrame:_videoFrame];
    }
    
    [_videoCaptureConsumer consumeFrame:_videoFrame];
    
    free(sanitizedImageBuffer);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
}

@end
