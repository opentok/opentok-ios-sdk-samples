//
//  TBExampleVideoCapture+PhotoCapture.m
//  Live-Photo-Capture
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "TBExamplePhotoVideoCapture.h"
#import <Availability.h>
#import <UIKit/UIKit.h>
#import <ImageIO/CGImageProperties.h>

@interface TBExamplePhotoVideoCapture()
@property (nonatomic) BOOL isTakingPhoto;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;
@end

@implementation TBExamplePhotoVideoCapture

- (NSString*)pauseVideoCaptureForPhoto {
    [self.captureSession beginConfiguration];
    NSString* oldPreset = self.captureSession.sessionPreset;
    [self.captureSession setSessionPreset:AVCaptureSessionPresetPhoto];
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc]
                                    initWithObjectsAndKeys:
                                    AVVideoCodecJPEG, AVVideoCodecKey,
                                    nil];
    [self.stillImageOutput setOutputSettings:outputSettings];
    [self.captureSession addOutput:self.stillImageOutput];
    [self.captureSession commitConfiguration];
    double startTime = CACurrentMediaTime();
    // if your images are coming out dark, you might try increasing this timeout
    double timeout = 1.0;
    while ((timeout > (CACurrentMediaTime() - startTime)) &&
           (self.videoInput.device.isAdjustingExposure ||
           self.videoInput.device.isAdjustingFocus)) {
        // wait for sensor to adjust. this should not take long
    }
    return oldPreset;
}

- (void)resumeVideoCapture:(NSString*)oldPreset {
    [self.captureSession beginConfiguration];
    [self.captureSession setSessionPreset:oldPreset];
    [self.captureSession removeOutput:self.stillImageOutput];
    [self.stillImageOutput release];
    [self.captureSession commitConfiguration];
}

- (UIImage*)doPhotoCapture {
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in self.stillImageOutput.connections)
    {
        for (AVCaptureInputPort *port in [connection inputPorts])
        {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] )
            {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection)
        {
            break;
        }
    }
    
    dispatch_semaphore_t imageCaptureSemaphore = dispatch_semaphore_create(0);
    __block UIImage* resultImage = nil;
    [self.stillImageOutput
     captureStillImageAsynchronouslyFromConnection:videoConnection
     completionHandler: ^(CMSampleBufferRef imageSampleBuffer,
                          NSError *error)
     {
         NSData *imageData =
         [AVCaptureStillImageOutput
          jpegStillImageNSDataRepresentation:imageSampleBuffer];
         resultImage = [[UIImage alloc] initWithData:imageData];
         dispatch_semaphore_signal(imageCaptureSemaphore);
     }];
    
    dispatch_time_t timeout = dispatch_walltime(DISPATCH_TIME_NOW,
                                                30 * NSEC_PER_SEC);
    dispatch_semaphore_wait(imageCaptureSemaphore, timeout);
    dispatch_release(imageCaptureSemaphore);
    
    return resultImage;
}

- (void)takePhotoWithCompletionHandler:(void (^)(UIImage* photo))block {
    if (self.isTakingPhoto) {
        return;
    }
    self.isTakingPhoto = YES;
    dispatch_async(_capture_queue, ^() {
        NSString* oldPreset = [self pauseVideoCaptureForPhoto];
        UIImage* result = [self doPhotoCapture];
        dispatch_async(dispatch_get_main_queue(), ^() {
            block([result autorelease]);
        });
        [self resumeVideoCapture:oldPreset];
        self.isTakingPhoto = NO;
    });
}

@end
