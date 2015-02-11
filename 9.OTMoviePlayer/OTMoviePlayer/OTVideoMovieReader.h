//
//  MyVideoCapture.h
//  OTMoviePlayer
//
//  Copyright (c) 2015 TokBox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <OpenTok/OpenTok.h>

@interface OTVideoMovieReader : NSObject <OTVideoCapture>

- (void) loadAsset:(AVURLAsset*) movieAsset;
- (void) sendVideoFrame:(double) currentTime;
- (void)initCapture;
- (void)releaseCapture;
- (int32_t)startCapture;
- (int32_t)stopCapture;
- (BOOL)isCaptureStarted;
- (int32_t)captureSettings:(OTVideoFormat*)videoFormat;

@end