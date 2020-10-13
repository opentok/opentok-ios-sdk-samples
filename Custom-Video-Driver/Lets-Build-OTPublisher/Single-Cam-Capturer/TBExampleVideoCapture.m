//
//  OTVideoCaptureIOSDefault.m
//  otkit-objc-libs
//
//  Created by Charley Robinson on 10/11/13.
//
//

#import <Availability.h>
#import <UIKit/UIKit.h>
#import "TBExampleVideoCapture.h"
#import <CoreVideo/CoreVideo.h>
#import "AppDelegate.h"

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


#define kTimespanWithNoFramesBeforeRaisingAnError 20.0 // NSTimeInterval(secs)

typedef NS_ENUM(int32_t, OTCapturerErrorCode) {

    OTCapturerSuccess = 0,

    /** Publisher couldn't access to the camera */
    OTCapturerError = 1650,

    /** Publisher's capturer is not capturing frames */
    OTCapturerNoFramesCaptured = 1660,

    /** Publisher's capturer authorization failed */
    OTCapturerAuthorizationDenied = 1670,
};


@interface TBExampleVideoCapture()
@property (nonatomic, strong) NSTimer *noFramesCapturedTimer;
@property (nonatomic) UIInterfaceOrientation currentStatusBarOrientation;
@end

@implementation TBExampleVideoCapture {
    __weak id<OTVideoCaptureConsumer> _videoCaptureConsumer;
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
    
    enum OTCapturerErrorCode _captureErrorCode;
    
    BOOL isFirstFrame;
}

@synthesize captureSession = _captureSession;
@synthesize delegate = _delegate;
@synthesize videoInput = _videoInput, videoOutput = _videoOutput;
@synthesize videoCaptureConsumer = _videoCaptureConsumer;

#define OTK_VIDEO_CAPTURE_IOS_DEFAULT_INITIAL_FRAMERATE 20

-(id)init {
    self = [super init];
    if (self) {
        _capturePreset = AVCaptureSessionPreset640x480;

        [[self class] dimensionsForCapturePreset:_capturePreset
                                           width:&_captureWidth
                                          height:&_captureHeight];
        _capture_queue = dispatch_queue_create("com.tokbox.OTVideoCapture",
                                               DISPATCH_QUEUE_SERIAL);
        _videoFrame = [[OTVideoFrame alloc] initWithFormat:
                      [OTVideoFormat videoFormatNV12WithWidth:_captureWidth
                                                       height:_captureHeight]];
        _currentStatusBarOrientation = UIInterfaceOrientationUnknown;
        isFirstFrame = false;
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(statusBarOrientationChange:)
         name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
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
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIApplicationWillChangeStatusBarOrientationNotification
     object:nil];
    [self stopCapture];
    [self releaseCapture];
    
    if (_capture_queue) {
        _capture_queue = nil;
    }
    _videoFrame = nil;
}

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position {
    NSArray *devices = [[AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified] devices];
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
    return [[[AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified] devices] count] > 1;
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

    if(lockConfiguration) [_captureSession commitConfiguration];
}

- (void)setActiveFrameRate:(double)frameRate {
    dispatch_async(_capture_queue, ^{
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
    dispatch_async(_capture_queue, ^{
        AVCaptureSession *session = [self captureSession];
        
        if ([session canSetSessionPreset:preset] &&
            ![preset isEqualToString:session.sessionPreset]) {
            
            [self->_captureSession beginConfiguration];
            self->_captureSession.sessionPreset = preset;
            self->_capturePreset = preset;
            
            [self->_videoOutput setVideoSettings:
             [NSDictionary dictionaryWithObjectsAndKeys:
              [NSNumber numberWithInt:
               kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
              kCVPixelBufferPixelFormatTypeKey,
              nil]];
            
            [self->_captureSession commitConfiguration];
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
    NSArray* devices = [[AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionUnspecified] devices];
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
    
    dispatch_async(_capture_queue, ^() {
        AVCaptureSession *session = [self captureSession];
        [session beginConfiguration];
        [session removeInput:self->_videoInput];
        BOOL success = YES;
        if ([session canAddInput:newVideoInput]) {
            [session addInput:newVideoInput];
            self->_videoInput = newVideoInput;
        } else {
            success = NO;
            [session addInput:self->_videoInput];
        }
        [session commitConfiguration];
        
        if (success) {
            [self setCaptureSessionPreset:preset];
        }
    });
    return;
}

- (void)releaseCapture {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVCaptureSessionRuntimeErrorNotification
                                                  object:nil];
    [self stopCapture];
    [_videoOutput setSampleBufferDelegate:nil queue:NULL];
    AVCaptureSession *session = _captureSession;
    dispatch_async(_capture_queue, ^() {
        [session stopRunning];
    });
    
    _captureSession = nil;
    _videoOutput = nil;
    _videoInput = nil;
    
    if (_blackFrameTimer) {
        _blackFrameTimer = nil;
    }
    
    free(_blackFrame);

}

- (void)setupAudioVideoSession {
    //-- Setup Capture Session.
    _captureErrorCode = OTCapturerSuccess;
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
        [self invalidateNoFramesTimerSettingItUpAgain:NO];
        OTError *err = [OTError errorWithDomain:OT_PUBLISHER_ERROR_DOMAIN
                                           code:OTCapturerError
                                       userInfo:nil];
        [self showCapturerError:err];
        [_captureSession commitConfiguration];
        _captureSession = nil;
        return;
    }
    
    //-- Add the device to the session.
    NSError *error;
    _videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice
                                                         error:&error];
    
    if (AVErrorApplicationIsNotAuthorizedToUseDevice == error.code) {
        [self initBlackFrameSender];
    }
    
    if(error || _videoInput == nil) {
        NSLog(@"ERROR[OpenTok]: Failed to initialize default video caputre "
              "session. (error=%@)", error);
        [self invalidateNoFramesTimerSettingItUpAgain:NO];
        OTError *err = [OTError errorWithDomain:OT_PUBLISHER_ERROR_DOMAIN
                                           code:(AVErrorApplicationIsNotAuthorizedToUseDevice
                                                 == error.code) ? OTCapturerAuthorizationDenied :
                                                 OTCapturerError
                                       userInfo:nil];
        [self showCapturerError:err];
        _videoInput = nil;
        [_captureSession commitConfiguration];
        _captureSession = nil;
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
    // The initial queue will be the main queue and then after receiving first frame,
    // we switch to _capture_queue. The reason for this is to detect initial
    // device orientation
    [_videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    [_captureSession addOutput:_videoOutput];
    
    [self setActiveFrameRateImpl
     : OTK_VIDEO_CAPTURE_IOS_DEFAULT_INITIAL_FRAMERATE : FALSE];
    
    [_captureSession commitConfiguration];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(captureSessionError:)
                                                 name:AVCaptureSessionRuntimeErrorNotification
                                               object:nil];

    [_captureSession startRunning];
}

- (void)captureSessionError:(NSNotification *)notification {
    [self invalidateNoFramesTimerSettingItUpAgain:NO];
    OTError *err = [OTError errorWithDomain:OT_PUBLISHER_ERROR_DOMAIN
                                       code:OTCapturerError
                                   userInfo:nil];
    NSError *captureSessionError = [notification.userInfo objectForKey:AVCaptureSessionErrorKey];
    NSLog(@"[OpenTok] AVCaptureSession error : %@", captureSessionError.localizedDescription);
    [self showCapturerError:err];
}

- (void)initCapture {
    dispatch_async(_capture_queue, ^{
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
    
    __weak TBExampleVideoCapture *weakSelf = self;
    if (_blackFrameTimer)
    {
        dispatch_source_set_timer(_blackFrameTimer, dispatch_walltime(NULL, 0),
                                  250ull * NSEC_PER_MSEC,
                                  1ull * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(_blackFrameTimer, ^{
            
            TBExampleVideoCapture *strongSelf = weakSelf;
            if (!strongSelf->_capturing) {
                return;
            }
            
            double now = CACurrentMediaTime();
            strongSelf->_videoFrame.timestamp =
            CMTimeMake((now - strongSelf->_blackFrameTimeStarted) * 90000, 90000);
            strongSelf->_videoFrame.format.imageWidth = blackFrameWidth;
            strongSelf->_videoFrame.format.imageHeight = blackFrameHeight;
            
            strongSelf->_videoFrame.format.estimatedFramesPerSecond = 4;
            strongSelf->_videoFrame.format.estimatedCaptureDelay = 0;
            strongSelf->_videoFrame.orientation = OTVideoOrientationUp;
            
            [strongSelf->_videoFrame clearPlanes];
            
            [strongSelf->_videoFrame.planes addPointer:yPlane];
            [strongSelf->_videoFrame.planes addPointer:uvPlane];
            
            [strongSelf->_videoCaptureConsumer consumeFrame:strongSelf->_videoFrame];
        });
        
        dispatch_resume(_blackFrameTimer);
    }
    
}

- (BOOL) isCaptureStarted {
    return (_captureSession || _blackFrameTimer) && _capturing;
}

- (int32_t) startCapture {
    _capturing = YES;
    if (!_blackFrameTimer) {
        // Do no set timer if blackframe is being sent
        [self invalidateNoFramesTimerSettingItUpAgain:YES];
    }
    return 0;
}

- (int32_t) stopCapture {
    _capturing = NO;
    [self invalidateNoFramesTimerSettingItUpAgain:NO];
    return 0;
}

- (void)invalidateNoFramesTimerSettingItUpAgain:(BOOL)value {
    [self.noFramesCapturedTimer invalidate];
    self.noFramesCapturedTimer = nil;
    if (value) {
        self.noFramesCapturedTimer = [NSTimer scheduledTimerWithTimeInterval:kTimespanWithNoFramesBeforeRaisingAnError
                                                                      target:self
                                                                    selector:@selector(noFramesTimerFired:)
                                                                    userInfo:nil
                                                                     repeats:NO];
    }
}

- (void)noFramesTimerFired:(NSTimer *)timer {
    if (self.isCaptureStarted) {
        OTError *err = [OTError errorWithDomain:OT_PUBLISHER_ERROR_DOMAIN
                                           code:OTCapturerNoFramesCaptured
                                       userInfo:nil];
        [self showCapturerError:err];
    }
}

- (void)statusBarOrientationChange:(NSNotification *)notification {
    self.currentStatusBarOrientation = [notification.userInfo[UIApplicationStatusBarOrientationUserInfoKey] integerValue];
}

- (OTVideoOrientation)currentDeviceOrientation {
    // transforms are different for
    if (AVCaptureDevicePositionFront == self.cameraPosition)
    {
        switch (self.currentStatusBarOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
                return OTVideoOrientationUp;
            case UIInterfaceOrientationLandscapeRight:
                return OTVideoOrientationDown;
            case UIInterfaceOrientationPortrait:
                return OTVideoOrientationLeft;
            case UIInterfaceOrientationPortraitUpsideDown:
                return OTVideoOrientationRight;
            case UIInterfaceOrientationUnknown:
                return OTVideoOrientationUp;
        }
    }
    else
    {
        switch (self.currentStatusBarOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
                return OTVideoOrientationDown;
            case UIInterfaceOrientationLandscapeRight:
                return OTVideoOrientationUp;
            case UIInterfaceOrientationPortrait:
                return OTVideoOrientationLeft;
            case UIInterfaceOrientationPortraitUpsideDown:
                return OTVideoOrientationRight;
            case UIInterfaceOrientationUnknown:
                return OTVideoOrientationUp;
        }
    }
    
    return OTVideoOrientationUp;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{

}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
    
    if (!(_capturing && _videoCaptureConsumer)) {
        return;
    }
    
    if (isFirstFrame == false)
    {
        isFirstFrame = true;
        _currentStatusBarOrientation = [[UIApplication sharedApplication] statusBarOrientation];;
        [_videoOutput setSampleBufferDelegate:self queue:_capture_queue];
    }

    if (self.noFramesCapturedTimer)
        [self invalidateNoFramesTimerSettingItUpAgain:NO];

    if ([self.delegate respondsToSelector:@selector(finishPreparingFrame:)]) {
          [self.delegate finishPreparingFrame:_videoFrame];
      }
    
    CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [_videoCaptureConsumer consumeImageBuffer:imageBuffer
                                  orientation:[self currentDeviceOrientation]
                                    timestamp:time
                                     metadata:_videoFrame.metadata];
    
}

-(void)showCapturerError:(OTError*)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Custom-Video-Driver"
                                                                                 message:[NSString stringWithFormat:
                                                                                          @"Capurer failed with error : %@", error.description]
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        //We add buttons to the alert controller by creating UIAlertActions:
        UIAlertAction *actionOk = [UIAlertAction actionWithTitle:@"Ok"
                                                           style:UIAlertActionStyleDefault
                                                         handler:nil]; //You can use a block here to handle a press on this button
        [alertController addAction:actionOk];
        [[[UIApplication sharedApplication] delegate].window.rootViewController
                                            presentViewController:alertController
                                            animated:YES completion:nil];
    });
}

@end

