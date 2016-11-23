//
//  OTMoviePlayer.m
//
//  Copyright (c) 2015 TokBox, Inc. All rights reserved.
//

#import "OTMoviePlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#import "OTAudioMovieReader.h"
#import "OTVideoMovieReader.h"

@implementation OTMoviePlayer
{
    OTVideoMovieReader* _videoDevice;
    OTAudioMovieReader* _audioDevice;
    NSURL* _assetURL;
}

@synthesize audioDevice = _audioDevice, videoCapture = _videoDevice;
@synthesize loop;

#pragma mark - Video Imp.

- (id)init {
    self = [super init];
    if (self) {    }
    return self;
}

- (void)dealloc
{
    [_videoDevice release];
    [_audioDevice release];
    [_assetURL release];
    [super dealloc];
}

- (void) loadMovieAssets:(NSURL *)assetURL
{
    if (nil != _assetURL) {
        [_assetURL release];
    }
    
    _assetURL = [assetURL copy];
    AVURLAsset* movieAsset = [AVURLAsset URLAssetWithURL:_assetURL options:nil];
    
    if (movieAsset == nil) {
        NSLog(@"asset is not defined!");
        return;
    }
    
    NSLog(@"Total Asset Duration: %f", CMTimeGetSeconds(movieAsset.duration));
    
    _audioDevice = [[OTAudioMovieReader alloc] init];
    _videoDevice = [[OTVideoMovieReader alloc] init];
    
    [_audioDevice loadAsset:movieAsset];
    [_videoDevice loadAsset:movieAsset];
    
    _audioDevice.listener = self;
}

- (void) wroteSamplesAtTime:(double) time
{
    [_videoDevice sendVideoFrame:time];
}

- (void) completedMovie
{
    if (NO == loop) { return ;}
    [_audioDevice stopCapture];
    AVURLAsset* movieAsset = [AVURLAsset URLAssetWithURL:_assetURL options:nil];
    [_audioDevice loadAsset:movieAsset];
    [_videoDevice loadAsset:movieAsset];
    [_audioDevice startCapture];
}

@end
