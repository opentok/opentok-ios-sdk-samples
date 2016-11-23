//
//  OTMoviePlayer.h
//
//  Copyright (c) 2015 TokBox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>
#import "OTAudioMovieReader.h"

/**
 TODO:  Because both the OTAudioDevice and OTVideoCapture have a fucking startCapture
        method I will have to separate them out of this movie player. Then I need
        to add properties to the moview player to get these interfaces in order to
        inject them into the SDK. I also will need to create interfaces that will
        allow the audio implementation to call to the movie player when it reads
        in audio. It will then need to call to the video caputure to read in 
        a frame of video when needed. 
 */

@interface OTMoviePlayer : NSObject <OTAudioMovieReaderListener>

@property (readonly) id<OTAudioDevice> audioDevice;
@property (readonly) id<OTVideoCapture> videoCapture;
@property (assign) BOOL loop;

- (void) loadMovieAssets:(NSURL *)assetURL_;

@end
