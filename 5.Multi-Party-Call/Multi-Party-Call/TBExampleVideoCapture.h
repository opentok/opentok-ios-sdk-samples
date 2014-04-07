//
//  TBExampleVideoCapture.h
//  OpenTok iOS SDK
//
//  Copyright (c) 2013 Tokbox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenTok/OpenTok.h>

@protocol OTVideoCapture;

@interface TBExampleVideoCapture : NSObject
    <AVCaptureVideoDataOutputSampleBufferDelegate, OTVideoCapture>
{
    @protected
    dispatch_queue_t _capture_queue;
}

@property (nonatomic, retain) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, retain) AVCaptureDeviceInput *videoInput;

@property (nonatomic, assign) NSString* captureSessionPreset;
@property (readonly) NSArray* availableCaptureSessionPresets;

@property (nonatomic, assign) double activeFrameRate;
- (BOOL)isAvailableActiveFrameRate:(double)frameRate;

@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;
@property (readonly) NSArray* availableCameraPositions;
- (BOOL)toggleCameraPosition;

@end
