//
//  TBExampleMultiCamCapture.h
//  Custom-Video-Driver
//
//  Created by Sridhar Bollam on 12/17/19.
//  Copyright © 2019 TokBox, Inc. All rights reserved.
//

#ifndef TBExampleMultiCamCapture_h
#define TBExampleMultiCamCapture_h

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenTok/OpenTok.h>

@protocol OTVideoCapture;

@interface TBExampleMultiCamCapture : NSObject
    <AVCaptureVideoDataOutputSampleBufferDelegate, OTVideoCapture>
{
    
}

-(id)initWithCameraPosition:(AVCaptureDevicePosition)camPosition
       andAVMultiCamSession:(AVCaptureMultiCamSession *)multiCamSession
                   useQueue:(dispatch_queue_t)capture_queue;

@property (nonatomic, weak) AVCaptureSession *captureSession;
@property (nonatomic, retain) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, retain) AVCaptureDeviceInput *videoInput;

@property (nonatomic, assign) AVCaptureDevicePosition cameraPosition;

@end

#endif /* TBExampleMultiCamCapture_h */
