//
//  SampleHandler.m
//  OpenTok Live
//
//  Created by Sridhar Bollam on 8/4/19.
//  Copyright © 2019 TokBox, Inc. All rights reserved.
//


#import "SampleHandler.h"
#import "OTBroadcastExtHelper.h"

// *** Fill the following variables using your own Project info  ***
// ***          https://dashboard.tokbox.com/projects            ***
// Replace with your OpenTok API key
static NSString* const kApiKey = @"47773081";
// Replace with your generated session ID
static NSString* const kSessionId = @"1_MX40Nzc3MzA4MX5-MTcwMTM2NzYyMzc4OX5INTMyUGJsT0FjM0oyVUE3RVpManI2eUJ-fn4";
// Replace with your generated token
static NSString* const kToken = @"T1==cGFydG5lcl9pZD00Nzc3MzA4MSZzaWc9MDJmYTdjMDMyY2FhMjNiNjJiYWU3MTU5MzI1NjRlY2IzYTQwMTQ4YTpzZXNzaW9uX2lkPTFfTVg0ME56YzNNekE0TVg1LU1UY3dNVE0yTnpZeU16YzRPWDVJTlRNeVVHSnNUMEZqTTBveVZVRTNSVnBNYW5JMmVVSi1mbjQmY3JlYXRlX3RpbWU9MTcwMTM2NzYyNCZub25jZT0wLjg1MTg2MzQ4ODU0MjE3MDUmcm9sZT1tb2RlcmF0b3ImZXhwaXJlX3RpbWU9MTcwMzk1OTYyNCZpbml0aWFsX2xheW91dF9jbGFzc19saXN0PQ==";

#define kVideoFrameScaleFactor 0.50
#define kVideoFrameProcessEvery3rdFrame 3

@implementation SampleHandler
{
    CVPixelBufferPoolRef _pixelBufferPool;
    CVPixelBufferRef _pixelBuffer;
    int64_t _num_frames;
    bool skip_frame;
    CIContext * _ciContext;
    CIFilter* _scaleFilter;
    bool _capturing;
    
    OTBroadcastExtHelper *_broadcastHelper;
    
    dispatch_queue_t _capture_queue;
    
}

- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    
    // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
    
    // Provide session id and token
    _broadcastHelper = [[OTBroadcastExtHelper alloc] initWithPartnerId:kApiKey
                                                             sessionId:kSessionId
                                                              andToken:kToken
                                                         videoCapturer:self];
    _capture_queue = dispatch_queue_create("com.tokbox.OTBroadcastVideoCapture",
                                           DISPATCH_QUEUE_SERIAL);
    
    _num_frames = 0;
    skip_frame = true;
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
    
    ciImage = [self scaleFilterImage:ciImage
                     withAspectRatio:1.0 scale:kVideoFrameScaleFactor];
    
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

- (bool)shouldSkipFrame
{
    if(_num_frames == kVideoFrameProcessEvery3rdFrame)
    {
        _num_frames = 0;
        return NO;
    } else
    {
        return YES;
    }
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
            if([self shouldSkipFrame])
                return;
               
            if([self->_broadcastHelper isConnected] && self->_capturing)
            {
                [self processPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer)
                               timeStamp:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
            }
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

@synthesize videoContentHint;

@end
