//
//  MyAudioDevice.h
//  OTMoviePlayer
//
//  Copyright (c) 2015 TokBox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

@protocol OTAudioMovieReaderListener <NSObject>
@required
- (void) wroteSamplesAtTime:(double) time;
- (void) completedMovie;
@end

@interface OTAudioMovieReader : NSObject <OTAudioDevice>

@property (assign) id<OTAudioMovieReaderListener> listener;

- (void) loadAsset:(AVURLAsset*) movieAsset;

- (BOOL)setAudioBus:(id<OTAudioBus>)audioBus;
- (OTAudioFormat*) audioFormat;
- (BOOL)renderingIsAvailable;
- (BOOL)initializeRendering;
- (BOOL)renderingIsInitialized;
- (BOOL)capturingIsAvailable;
- (BOOL)initializeCapture;
- (BOOL)captureIsInitialized;

- (BOOL)startRendering;
- (BOOL)stopRendering;
- (BOOL)isRendering;
- (BOOL)startCapture;
- (BOOL)stopCapture;
- (BOOL)videoCapturing;

- (uint16_t)estimatedRenderDelay;
- (uint16_t)estimatedCaptureDelay;

@end