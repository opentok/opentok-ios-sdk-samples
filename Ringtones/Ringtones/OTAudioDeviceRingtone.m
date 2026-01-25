//
//  OTAudioPlayer.m
//  Ringtones
//
//  Created by Charley Robinson on 2/16/16.
//  Copyright © 2016 TokBox, Inc. All rights reserved.
//

#import "OTAudioDeviceRingtone.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioServices.h>

#define VIBRATE_FREQUENCY_SECONDS 1.0f

@interface OTAudioDeviceRingtone() <AVAudioPlayerDelegate>

@end

@implementation OTAudioDeviceRingtone {
    AVAudioPlayer* _audioPlayer;
    BOOL _vibratesWithRingtone;
    NSTimer* _vibrateTimer;
    NSURL * ringtoneURL;
}

@synthesize vibratesWithRingtone = _vibratesWithRingtone;

- (instancetype)initWithRingtone:(NSURL *)url {
    self = [super init];
    if (self) {
        ringtoneURL = url;
    }
   
    return self;
}
// Make sure OT audio is initilaized before you call this method.
// Else publisher's will timeout with error.
- (void)playRingtoneFromURL:(NSURL*)url
{
    [self stopCapture];
    [self stopRendering];
    // Stop & replace existing audio player
    if (_audioPlayer) {
        [_audioPlayer stop];
        _audioPlayer = nil;
    }
    
    NSError* error = nil;
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url
                                                          error:&error];
    if (error) {
        NSLog(@"Ringtone audio player initialization failure %@", error);
        _audioPlayer = nil;
        return;
    }
    [_audioPlayer setDelegate:self];
    
    // Tell player to loop indefinitely
    [_audioPlayer setNumberOfLoops:-1];

    // setup timer to vibrate device with some frequency
    if (_vibratesWithRingtone) {
        _vibrateTimer =
        [NSTimer scheduledTimerWithTimeInterval:VIBRATE_FREQUENCY_SECONDS
                                         target:self
                                       selector:@selector(buzz:)
                                       userInfo:nil
                                        repeats:YES];
    }
    
    // finally, begin playback
    [_audioPlayer play];
}

- (void)buzz:(NSTimer*)timer {
    if (_vibratesWithRingtone) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}



#pragma mark - OTDefaultAudioDevice overrides

// The following callbacks are overridden just in case you want to add logs etc.
// You could have made a call to the parent methods directly.

- (BOOL)startRendering
{
    return [super startRendering];
}

- (BOOL)stopRendering
{
    return [super stopRendering];
}

- (BOOL)startCapture
{
    return [super startCapture];
}

- (BOOL)stopCapture
{
    return [super stopCapture];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError * __nullable)error
{
    NSLog(@"audioPlayerDecodeErrorDidOccur %@", error);
    [self stopRingtone];
}

#pragma mark - Exposed interface methods
- (void)startRingtone {
    if (_audioPlayer == nil) {
        [self playRingtoneFromURL:ringtoneURL];
    }
}

- (void)stopRingtone {
    // Stop Audio
    [_audioPlayer stop];
    _audioPlayer = nil;
    
    // Stop vibration
    [_vibrateTimer invalidate];
    _vibrateTimer = nil;
    
    [self startCapture];
    [self startRendering];

}

- (BOOL)isRingTonePlaying {
    return _audioPlayer != nil;
}

@end
