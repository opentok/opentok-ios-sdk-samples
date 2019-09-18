//
//  SampleHandler.m
//  OpenTok Live
//
//  Created by Sridhar Bollam on 8/4/19.
//  Copyright © 2019 TokBox, Inc. All rights reserved.
//


#import "SampleHandler.h"
#import "OTBroadcastExtHelper.h"

@implementation SampleHandler
{
    CVPixelBufferPoolRef _pixelBufferPool;
    CVPixelBufferRef _pixelBuffer;
    int64_t _num_frames;
    CIContext * _ciContext;
    CIFilter* _scaleFilter;
    bool _capturing;
    
    OTBroadcastExtHelper *_broadcastHelper;
    
    dispatch_queue_t _capture_queue;
    
}

- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    
    // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
    
    // Provide session id and token
    _broadcastHelper = [[OTBroadcastExtHelper alloc] initWithPartnerId:@""
                                                             sessionId: @""
                                                              andToken:@""
                                                         videoCapturer:self];
    _capture_queue = dispatch_queue_create("com.tokbox.OTBroadcastVideoCapture",
                                           DISPATCH_QUEUE_SERIAL);
    
    _num_frames = 0;
    [self destroyPixelBuffers];
    [_broadcastHelper connect];
}

- (void)broadcastPaused {
    // User has requested to pause the broadcast. Samples will stop being delivered.
}

- (void)broadcastResumed {
    // User has requested to resume the broadcast. Samples delivery will resume.
}

- (void)broadcastFinished {
    // User has requested to finish the broadcast.
    [_broadcastHelper disconnect];
}

- (void) processPixelBuffer:(CVPixelBufferRef)pixelBuffer timeStamp:(CMTime)ts
{
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer
                                               options:nil];
    //CGFloat imageWidth = CVPixelBufferGetWidth(pixelBuffer);
    //CGFloat imageHeight = CVPixelBufferGetHeight(pixelBuffer);
    CGFloat aspectRatio = 1;//imageHeight / imageWidth;
    
    ciImage = [self scaleFilterImage:ciImage
                     withAspectRatio:aspectRatio scale:0.60];
    
    if(_pixelBufferPool == nil ||
       CVPixelBufferGetWidth(pixelBuffer) != CVPixelBufferGetWidth(_pixelBuffer) ||
       CVPixelBufferGetHeight(pixelBuffer) != CVPixelBufferGetHeight(_pixelBuffer))
    {
        [self destroyPixelBuffers];
        [self createPixelBufferPoolWithWidth:ciImage.extent.size.width
                                      height:ciImage.extent.size.height];
        CVPixelBufferPoolCreatePixelBuffer(NULL, _pixelBufferPool, &_pixelBuffer);
    }
    
    [_ciContext render:ciImage toCVPixelBuffer:_pixelBuffer];
    
    [self.videoCaptureConsumer consumeImageBuffer:_pixelBuffer
                                      orientation:OTVideoOrientationUp
                                        timestamp:ts
                                         metadata:nil];
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    
    switch (sampleBufferType) {
        case RPSampleBufferTypeVideo:
        {
            // Handle video sample buffer
            
            // Codec limits to avoid reaching over 50MB memory
            // Tested on iPhone 8
            // VP8  : Height = 800, Width = 450, fps = 10
            // H264 : Height = 1068, Width = 600, fps = 15 or more
            _num_frames++;
            if (_num_frames % 3 != 0)
                return;
            
            //            CFRetain(sampleBuffer);
            //dispatch_async(_capture_queue, ^{
            if([self->_broadcastHelper isConnected] && self->_capturing)
            {
                [self processPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer)
                               timeStamp:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
                //CFRelease(sampleBuffer);
            }
            //});
        }
            break;
        case RPSampleBufferTypeAudioApp:
        {
            // Handle audio sample buffer for app audio
        }
            break;
        case RPSampleBufferTypeAudioMic:
        {
            // Handle audio sample buffer for mic audio
            if([_broadcastHelper isConnected])
            {
                [_broadcastHelper writeAudioSamples:sampleBuffer];
            }
        }
            break;
            
        default:
            break;
    }
}

- (void)initCapture {
    _scaleFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
    _ciContext = [CIContext contextWithOptions: nil];
}

- (void)releaseCapture {
    _ciContext = nil;
    _scaleFilter = nil;
    [self destroyPixelBuffers];
}

- (int32_t)startCapture
{
    dispatch_async(_capture_queue, ^{
        self->_capturing = YES;
    });
    return 0;
}

- (int32_t)stopCapture
{
    dispatch_async(_capture_queue, ^{
        self->_capturing = NO;
    });
    
    return 0;
}

- (BOOL)isCaptureStarted
{
    return _capturing;
}

- (int32_t)captureSettings:(OTVideoFormat*)videoFormat
{
    videoFormat.pixelFormat = OTPixelFormatARGB;
    return 0;
}

-(void)destroyPixelBuffers
{
    if(_pixelBuffer)
        CVPixelBufferRelease(_pixelBuffer);
    _pixelBuffer = nil;
    
    if(_pixelBufferPool)
        CVPixelBufferPoolRelease(_pixelBufferPool);
    _pixelBufferPool = nil;
}

- (void)createPixelBufferPoolWithWidth:(int)width height:(int)height
{
    
    [self destroyPixelBuffers];
    OSType pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
    
    CFMutableDictionaryRef sourcePixelBufferOptions = CFDictionaryCreateMutable( kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks );
    CFNumberRef number = CFNumberCreate( kCFAllocatorDefault, kCFNumberSInt32Type, &pixelFormat );
    CFDictionaryAddValue( sourcePixelBufferOptions, kCVPixelBufferPixelFormatTypeKey, number );
    CFRelease( number );
    
    number = CFNumberCreate( kCFAllocatorDefault, kCFNumberSInt32Type, &width );
    CFDictionaryAddValue( sourcePixelBufferOptions, kCVPixelBufferWidthKey, number );
    CFRelease( number );
    
    number = CFNumberCreate( kCFAllocatorDefault, kCFNumberSInt32Type, &height );
    CFDictionaryAddValue( sourcePixelBufferOptions, kCVPixelBufferHeightKey, number );
    CFRelease( number );
    
    ((__bridge NSMutableDictionary *)sourcePixelBufferOptions)[(id)kCVPixelBufferIOSurfacePropertiesKey] = @{ @"IOSurfaceIsGlobal" : @YES };
    
    CVPixelBufferPoolCreate( kCFAllocatorDefault, NULL, sourcePixelBufferOptions, &_pixelBufferPool);
}

- (CIImage*) scaleFilterImage: (CIImage*)inputImage withAspectRatio:(CGFloat)aspectRatio scale:(CGFloat)scale
{
    [_scaleFilter setValue:inputImage forKey:kCIInputImageKey];
    [_scaleFilter setValue:@(scale) forKey:kCIInputScaleKey];
    //[scaleFilter setValue:@(aspectRatio) forKey:kCIInputAspectRatioKey];
    return _scaleFilter.outputImage;
}

@end
