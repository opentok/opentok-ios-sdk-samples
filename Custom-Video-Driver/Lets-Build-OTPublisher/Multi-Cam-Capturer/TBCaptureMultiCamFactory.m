//
//  OTAVMultiCamSession.m
//  Custom-Video-Driver
//
//  Created by Sridhar Bollam on 12/17/19.
//  Copyright © 2019 TokBox, Inc. All rights reserved.
//

#import "TBCaptureMultiCamFactory.h"


@implementation TBCaptureMultiCamFactory
static TBCaptureMultiCamFactory* _otMultiCamAudioSession = nil;

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _otMultiCamAudioSession = [[TBCaptureMultiCamFactory alloc] init];
        _otMultiCamAudioSession.capturer_queue = dispatch_queue_create("ot-multicam-capturer", DISPATCH_QUEUE_SERIAL);
        if (@available(iOS 13.0, *))
            _otMultiCamAudioSession.avCaptureMultiCamSession = [[AVCaptureMultiCamSession alloc] init];
    });
}

+ (id)sharedInstance
{
    return _otMultiCamAudioSession;
}

- (TBExampleMultiCamCapture *)createCapturerForCameraPosition:(AVCaptureDevicePosition)camPosition
{
    TBExampleMultiCamCapture *multiCamCapture = [[TBExampleMultiCamCapture alloc]
                                                 initWithCameraPosition:camPosition
                                                 andAVMultiCamSession:self.avCaptureMultiCamSession
                                                 useQueue:self.capturer_queue];
    dispatch_async(self.capturer_queue, ^{
        // Adjust camera resolution and/or framerate based on system cost
        [_otMultiCamAudioSession checkSystemCost];
    });
    return multiCamCapture;
}

- (void)checkSystemCost
{
    if([[TBCaptureMultiCamFactory sharedInstance] avCaptureMultiCamSession].outputs.count < 2)
        return;
    BOOL exceededPressureCost = ([[TBCaptureMultiCamFactory sharedInstance] avCaptureMultiCamSession].systemPressureCost > 1);
    BOOL exceededHardwareCost = ([[TBCaptureMultiCamFactory sharedInstance] avCaptureMultiCamSession].hardwareCost > 1);
    if(exceededPressureCost || exceededHardwareCost)
    {
        if ([self reduceResolutionForCamera:AVCaptureDevicePositionFront]) {
            [self checkSystemCost];
        } else if ([self reduceResolutionForCamera:AVCaptureDevicePositionBack]) {
            [self checkSystemCost];
        } else if ([self reduceFrameRateForCamera:AVCaptureDevicePositionFront]) {
            [self checkSystemCost];
        } else if ([self reduceFrameRateForCamera:AVCaptureDevicePositionBack]) {
            [self checkSystemCost];
        } else {
            NSLog(@"[OpenTok] Unable to reduce AVCaptureMultiCamSession cost!");
        }
    }
}

/* Ported from Apple's MultiCam Swift Sample code */
- (BOOL)reduceResolutionForCamera:(AVCaptureDevicePosition)position
{
    if (@available(iOS 13.0, *))
    {
        for(AVCaptureConnection *connection in [[[TBCaptureMultiCamFactory sharedInstance] avCaptureMultiCamSession] connections])
        {
            for(AVCaptureInputPort *inputPort in connection.inputPorts)
            {
                if(inputPort.mediaType == AVMediaTypeVideo && inputPort.sourceDevicePosition == position)
                {
                    AVCaptureDeviceInput *videoDeviceInput = (AVCaptureDeviceInput *)inputPort.input;
                    
                    CMVideoDimensions dims;
                    int width = 0, height = 0, activeWidth = 0, activeHeight = 0;
                    
                    dims = CMVideoFormatDescriptionGetDimensions(videoDeviceInput.device.activeFormat.formatDescription);
                    activeWidth = dims.width;
                    activeHeight = dims.height;
                    
                    if (activeHeight <= 480  &&  activeWidth <= 640) {
                        return false;
                    }
                    NSArray<AVCaptureDeviceFormat *> *formats = videoDeviceInput.device.formats;
                    NSUInteger formatIndex = [formats indexOfObject:videoDeviceInput.device.activeFormat];
                    if(formatIndex == NSNotFound)
                        formatIndex = 0;
                    formatIndex -= 1;
                    
                    for (NSUInteger index = formatIndex; index >= 0 ; index--)
                    {
                        AVCaptureDeviceFormat *format = videoDeviceInput.device.formats[index];
                        if(!format.isMultiCamSupported ||
                        [format.supportedColorSpaces containsObject:
                         [NSNumber numberWithInt:AVCaptureColorSpace_P3_D65]] == YES) // wide color costs more cpu!
                         continue;
                        
                        dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                        width = dims.width;
                        height = dims.height;
                        
                        if (width < activeWidth || height < activeHeight)
                        {
                            NSError *error = nil;
                            if ([videoDeviceInput.device lockForConfiguration:&error]) {
                                videoDeviceInput.device.activeFormat = format;
                                [videoDeviceInput.device unlockForConfiguration];
                                NSLog(@"Reduced width and height to %dX%d", width, height);
                                return true;
                            } else {
                                //Handle Error
                                NSLog(@"Unable to reduce resolution (failed to acquire the lock!)");
                                return false;
                            }
                            
                        }
                    }
                }
            }
        }
    }
    return false;
}

- (BOOL)reduceFrameRateForCamera:(AVCaptureDevicePosition)position
{
    if (@available(iOS 13.0, *))
    {
        for(AVCaptureConnection *connection in [[[TBCaptureMultiCamFactory sharedInstance] avCaptureMultiCamSession] connections])
        {
            for(AVCaptureInputPort *inputPort in connection.inputPorts)
            {
                if(inputPort.mediaType == AVMediaTypeVideo && inputPort.sourceDevicePosition == position)
                {
                    AVCaptureDeviceInput *videoDeviceInput = (AVCaptureDeviceInput *)inputPort.input;
                    
                    CMTime activeMinFrameDuration = videoDeviceInput.device.activeVideoMinFrameDuration;
                    double activeMaxFrameRate = (double)activeMinFrameDuration.timescale / (double)activeMinFrameDuration.value;
                    activeMaxFrameRate -= 10.0;
                    
                    // Cap the device frame rate to this new max, never allowing it to go below 15 fps
                    if (activeMaxFrameRate >= 15.0) {
                            NSError *error = nil;
                            if ([videoDeviceInput.device lockForConfiguration:&error]) {
                                videoDeviceInput.videoMinFrameDurationOverride = CMTimeMake (1, activeMaxFrameRate);
                                [videoDeviceInput.device unlockForConfiguration];
                                NSLog(@"Reduced frame rate to %f", activeMaxFrameRate);
                                return true;
                            } else {
                                //Handle Error
                                NSLog(@"Unable to reduce resolution (failed to acquire the lock!)");
                                return false;
                            }
                    } else {
                        return false;
                    }


                }
            }
        }
    }
    return false;
}

@end
