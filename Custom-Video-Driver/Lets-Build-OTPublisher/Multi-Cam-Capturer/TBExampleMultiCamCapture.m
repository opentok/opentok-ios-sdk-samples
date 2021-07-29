//
//  TBExampleMultiCamCapture.m
//  Custom-Video-Driver
//
//  Created by Sridhar Bollam on 12/17/19.
//  Copyright © 2019 TokBox, Inc. All rights reserved.
//

#import <Availability.h>
#import <UIKit/UIKit.h>
#import "TBExampleMultiCamCapture.h"
#import <CoreVideo/CoreVideo.h>
#import "AppDelegate.h"

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


@interface TBExampleMultiCamCapture()
@property (nonatomic, strong) NSTimer *noFramesCapturedTimer;
@property (nonatomic) UIInterfaceOrientation currentStatusBarOrientation;
@end

@implementation TBExampleMultiCamCapture {
    __weak id<OTVideoCaptureConsumer> _videoCaptureConsumer;
    OTVideoFrame* _videoFrame;
    
    uint32_t _captureWidth;
    uint32_t _captureHeight;;
    
    dispatch_queue_t _capture_queue;
    // OTAVMultiCamSession holds capture session
    __weak AVCaptureMultiCamSession *_captureSession;
     AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCaptureDevicePosition _camPosition;

    BOOL _capturing;
    
    dispatch_source_t _blackFrameTimer;
    uint8_t* _blackFrame;
    double _blackFrameTimeStarted;
    
    enum OTCapturerErrorCode _captureErrorCode;
    
    BOOL isFirstFrame;
}

@synthesize videoCaptureConsumer = _videoCaptureConsumer;
@synthesize videoContentHint;

-(id)initWithCameraPosition:(AVCaptureDevicePosition)camPosition
         andAVMultiCamSession:(AVCaptureMultiCamSession *)multiCamSession
                   useQueue:(dispatch_queue_t)capture_queue
{
    self = [super init];
    if (self) {

        _camPosition = camPosition;
        _captureSession = multiCamSession;
        _capture_queue = capture_queue;
        
        _captureWidth = 1280;
        _captureHeight = 720;
        
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
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVCaptureSessionRuntimeErrorNotification
                                                  object:nil];
    [self stopCapture];
    if (_blackFrameTimer) {
          _blackFrameTimer = nil;
    }
    free(_blackFrame);
    
    [self releaseCapture];
    
    _videoFrame = nil;
}

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position {
    return [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                              mediaType:AVMediaTypeVideo
                                               position:position];
}

- (AVCaptureDevice *) frontFacingCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

- (AVCaptureDevice *) backFacingCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

- (void)updateCaptureFormatWithWidth:(uint32_t)width height:(uint32_t)height
{
    _captureWidth = width;
    _captureHeight = height;
    [_videoFrame setFormat:[OTVideoFormat
                           videoFormatNV12WithWidth:_captureWidth
                           height:_captureHeight]];
    
}

- (void) setCaptureFormatWidth:(int)width height:(int)height {
    
    dispatch_async(_capture_queue, ^{
        for (int i = (int)self->_videoInput.device.formats.count - 1; i >= 0; i--) {
            CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(self->_videoInput.device.formats[i].formatDescription);
            if(dimensions.width <= width ||
               dimensions.height <= height)
            {
                
                if(!self->_videoInput.device.formats[i].isMultiCamSupported ||
                   [self->_videoInput.device.formats[i].supportedColorSpaces containsObject:
                    [NSNumber numberWithInt:AVCaptureColorSpace_P3_D65]] == YES) // wide color costs more cpu!
                    continue;
                 NSError *error;
                if([self->_videoInput.device lockForConfiguration:&error])
                {

                    self->_videoInput.device.activeFormat = self->_videoInput.device.formats[i];
                    [self->_videoInput.device unlockForConfiguration];
                } else
                {
                    NSLog(@"[OpenTok] Unable to lock the device!");
                }
                break;
            }
        }
    });
}

- (void)releaseCapture {
    AVCaptureDevicePosition camPosition = _camPosition;
    AVCaptureDeviceInput *videoInput = _videoInput;
    AVCaptureVideoDataOutput *videoOutput = _videoOutput;
    AVCaptureMultiCamSession *captureSession = _captureSession;
    
    dispatch_async(_capture_queue, ^{
        
        [captureSession beginConfiguration];
        
        AVCaptureConnection *currentConnection = nil;
        for(currentConnection in captureSession.connections)
        {
            if(currentConnection.inputPorts.count > 0 &&
               ((AVCaptureDeviceInput *)currentConnection.inputPorts[0].input).device.position == camPosition)
                break;
        }
        if(currentConnection)
            [captureSession removeConnection:currentConnection];
        [captureSession removeInput:videoInput];
        [captureSession removeOutput:videoOutput];
        
        [captureSession commitConfiguration];
        
        if([captureSession.outputs count] == 0) // stop capture session, when last publisher unpublished!
        {
            [captureSession stopRunning];
        }
    });

}

- (void)setupAudioVideoSession {
    //-- Setup Capture Session.
    _captureErrorCode = OTCapturerSuccess;
    
    if(_captureSession == nil)
    {
        NSDictionary *errorDictionary = @{ NSLocalizedDescriptionKey : @"Device won't support multiple cameras!"};
        OTError *err = [OTError errorWithDomain:OT_PUBLISHER_ERROR_DOMAIN
                                                  code:OTCapturerError
                                              userInfo:errorDictionary];
        [self showCapturerError:err];
        return;
    }
    
    [_captureSession beginConfiguration];
    
    _captureSession.usesApplicationAudioSession = NO;
    
    
    //-- Create a video device and input from that Device.
    // Add the input to the capture session.
    AVCaptureDevice * videoDevice = nil;
    if(_camPosition == AVCaptureDevicePositionFront)
        videoDevice = [self frontFacingCamera];
    else
        videoDevice = [self backFacingCamera];
    
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
        NSLog(@"ERROR[OpenTok]: Failed to initialize video caputre "
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
    
    // We will be adding manual connection as recommended in Apple's MultiCam sample
    [_captureSession addInputWithNoConnections:_videoInput];
    
    
    //-- Create the output for the capture session.
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setAlwaysDiscardsLateVideoFrames:YES];
    
    [_videoOutput setVideoSettings:
     [NSDictionary dictionaryWithObject:
      [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
                                 forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    
    // The initial queue will be the main queue and then after receiving first frame,
    // we switch to [[OTAVMultiCamSession sharedInstance] capturer_queue].
    // The reason for this is to detect initial device orientation
    [_videoOutput setSampleBufferDelegate:self queue:dispatch_get_main_queue()];
    
    [_captureSession addOutputWithNoConnections:_videoOutput];
    
    // configure connections
    NSUInteger inputPortIndex = [_videoInput.ports indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        return ([(AVCaptureInputPort *)obj mediaType] == AVMediaTypeVideo &&
                [(AVCaptureInputPort *)obj sourceDeviceType] == _videoInput.device.deviceType &&
                [(AVCaptureInputPort *)obj sourceDevicePosition] == _videoInput.device.position);
    }];
    if(inputPortIndex == NSNotFound)
    {
        NSLog(@"Could not find the front camera device input's video port");
        [_captureSession commitConfiguration];
        _captureSession = nil;
        _videoOutput = nil;
        _videoInput = nil;
        return;
    }
    
    AVCaptureConnection *videoDataOutputConnection = [[AVCaptureConnection alloc] initWithInputPorts:@[_videoInput.ports[inputPortIndex]]
                                                                                              output:_videoOutput];
    [_captureSession addConnection:videoDataOutputConnection];
    if(_videoInput.device.position == AVCaptureDevicePositionFront)
    {
        videoDataOutputConnection.automaticallyAdjustsVideoMirroring = false;
    }
    // end of configure connections
    
    [_captureSession commitConfiguration];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(captureSessionError:)
                                                 name:AVCaptureSessionRuntimeErrorNotification
                                               object:nil];

    [self setCaptureFormatWidth:_captureWidth height:_captureHeight];
    
    if(!_captureSession.running)
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
    
    __weak TBExampleMultiCamCapture *weakSelf = self;
    if (_blackFrameTimer)
    {
        dispatch_source_set_timer(_blackFrameTimer, dispatch_walltime(NULL, 0),
                                  250ull * NSEC_PER_MSEC,
                                  1ull * NSEC_PER_MSEC);
        dispatch_source_set_event_handler(_blackFrameTimer, ^{
            
            TBExampleMultiCamCapture *strongSelf = weakSelf;
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
    if (AVCaptureDevicePositionFront == _camPosition)
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

    CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [_videoCaptureConsumer consumeImageBuffer:imageBuffer
                                  orientation:[self currentDeviceOrientation]
                                    timestamp:time
                                     metadata:nil];
    
}

-(void)showCapturerError:(OTError*)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Custom-Video-Driver"
                                                                                 message:[NSString stringWithFormat:
                                                                                          @"Capturer failed with error : %@", error.description]
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
