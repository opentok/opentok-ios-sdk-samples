//
//  MyVideoCapture.m
//  OTMoviePlayer
//
//  Copyright (c) 2015 TokBox, Inc. All rights reserved.
//

#import "OTVideoMovieReader.h"

@interface OTVideoMovieReader ()
- (void) loadVideoFrame;
@end

@implementation OTVideoMovieReader
{
    OTVideoFrame* _frameHolder;
    CMSampleBufferRef _videoBuffer;
    CMTime _lastTimeStamp;
    CGSize _frameSize;
    dispatch_queue_t _decodeQueue;
    BOOL _videoCapturing;
    
    AVAssetReader* videoAssetReader;
    AVAssetReaderOutput *videoReaderOutput;
}

@synthesize videoCaptureConsumer;

- (instancetype)init
{
    self = [super init];
    if (self) {
        _videoCapturing = NO;
        _decodeQueue = dispatch_queue_create("sample-queue", 0);
    }
    return self;
}

- (void) loadAsset:(AVURLAsset*) movieAsset
{
    NSError *error=[[NSError alloc]init];
    
    /* allocate assetReader */
    videoAssetReader = [[AVAssetReader alloc] initWithAsset:movieAsset
                                                      error:&error];
    
    /* get video track(s) from movie asset */
    NSArray *videoTracks = [movieAsset tracksWithMediaType:AVMediaTypeVideo];
    
    /* get first video track, if there is any */
    AVAssetTrack *videoTrack0 = [videoTracks objectAtIndex:0];
    
    /* determine image dimensions of images stored in movie asset */
    _frameSize = [videoTrack0 naturalSize];
    NSLog(@"movie asset natual size: size.width=%f size.height=%f",
          _frameSize.width, _frameSize.height);
    
    /* Ensure our send buffer is setup for this video. Since we're asking
     * AVFoundation for NV12, we'll do the same here.
     */
    OTVideoFormat* format =
    [OTVideoFormat videoFormatNV12WithWidth:_frameSize.width
                                     height:_frameSize.height];
    
    _frameHolder = [[OTVideoFrame alloc] initWithFormat:format];
    
    /* set the desired video frame format into attribute dictionary */
    NSDictionary* dictionary =
    [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
     (NSString*)kCVPixelBufferPixelFormatTypeKey,
     nil];
    
    /* construct the actual track output and add it to the asset reader */
    videoReaderOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:videoTrack0
                                                         outputSettings:dictionary];
    
    if([videoAssetReader canAddOutput:videoReaderOutput]){
        [videoAssetReader addOutput:videoReaderOutput];
    }
    else {
        assert(false);
    }
    
    if (NO == [videoAssetReader startReading]) {
        assert(false);
    }
    
    [self loadVideoFrame];
}

- (void)sendSampleBuffer:(CMTime)timestamp
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(_videoBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // clear previous pointers
    [_frameHolder.planes setCount:0];
    
    // copy new pointers
    for (int i = 0; i < CVPixelBufferGetPlaneCount(imageBuffer); i++) {
        uint8_t* plane = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, i);
        [_frameHolder.planes addPointer:plane];
    }
    
    // No need to rotate since we're just reading from a file.
    _frameHolder.orientation = OTVideoOrientationUp;
    
    // Copy the timestamp from the video
    _frameHolder.timestamp = timestamp;
    
    // Send the frame to OpenTok.
    [videoCaptureConsumer consumeFrame:_frameHolder];
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
    
    CFRelease(_videoBuffer);
}

- (void) loadVideoFrame
{
    _videoBuffer = [videoReaderOutput copyNextSampleBuffer];
}

- (void) sendVideoFrame:(double) currentTime
{
    CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;
    CMSampleBufferGetSampleTimingInfo(_videoBuffer, 0, &timingInfo);
    CMTime currentTS = timingInfo.presentationTimeStamp;
    
    double video_time = (double) currentTS.value / (double)currentTS.timescale;
    
    if (video_time <= currentTime) {
        [self sendSampleBuffer:timingInfo.presentationTimeStamp];
        _videoBuffer = NULL;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadVideoFrame];
        });
    }
}

- (void)initCapture {
    
}

- (void)releaseCapture {
    
}

- (void)setupCaptureSession {
    
}

- (int32_t)startCapture {
    _videoCapturing = YES;
//    dispatch_async(_decodeQueue, ^() {
//        @autoreleasepool {
//            while (_videoCapturing) {
//                [self setupCaptureSession];
//            }
//        }
//    });
    return 0;
}

- (int32_t)stopCapture {
    _videoCapturing = NO;
    return 0;
}

- (BOOL)isCaptureStarted {
    return _videoCapturing;
}

- (int32_t)captureSettings:(OTVideoFormat*)videoFormat {
    // We don't know at the time this is called, so skip this function.
    return 0;
}

@end