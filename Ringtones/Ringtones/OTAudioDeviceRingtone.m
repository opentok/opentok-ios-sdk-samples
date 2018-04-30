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
@property (nonatomic) AVAudioPlayer *audioPlayer;
@property (nonatomic) NSMutableArray *deferredCallbacks;
@property (nonatomic) NSTimer *vibrateTimer;
@end

@implementation OTAudioDeviceRingtone

- (instancetype)init {
    if (self = [super init]) {
        _deferredCallbacks = [NSMutableArray new];
    }
    return self;
}

- (void)playRingtoneFromURL:(NSURL*)url
{
    // Stop & replace existing audio player
    if (self.audioPlayer) {
        [self.audioPlayer stop];
        self.audioPlayer = nil;
    }
    
    NSError* error = nil;
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url
                                                          error:&error];
    if (error) {
        NSLog(@"Ringtone audio player initialization failure %@", error);
        self.audioPlayer = nil;
        return;
    }
    [self.audioPlayer setDelegate:self];
    
    // Tell player to loop indefinitely
    [self.audioPlayer setNumberOfLoops:-1];
    
    // Allow background playback, only if the default driver hasn't already
    // started running. Setting the category while the audio session is
    // configured for voice chat (PlayAndRecord) will interrupt recording and
    // cause problems if a publisher is running.
    if (!self.isCapturing && !self.isRendering) {
        AVAudioSession* audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayback
                            error:nil];
        [audioSession setActive:YES error:nil];
    }
    
    // setup timer to vibrate device with some frequency
    if (self.vibratesWithRingtone) {
        self.vibrateTimer =
        [NSTimer scheduledTimerWithTimeInterval:VIBRATE_FREQUENCY_SECONDS
                                         target:self
                                       selector:@selector(buzz:)
                                       userInfo:nil
                                        repeats:YES];
    }
    
    // finally, begin playback
    [self.audioPlayer play];
}

- (void)stopRingtone {
    // Stop Audio
    [self.audioPlayer stop];
    self.audioPlayer = nil;
    
    // Stop vibration
    [self.vibrateTimer invalidate];
    self.vibrateTimer = nil;
    
    // Allow deferred audio callback calls to flow
    [self flushDeferredCallbacks];
}

- (void)buzz:(NSTimer*)timer {
    if (self.vibratesWithRingtone) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    }
}

/**
 * Private method: Can't always do as requested immediately. Defer incoming
 * callbacks from OTAudioBus until we aren't playing anything back
 */
- (void)enqueueDeferredCallback:(SEL)callback
{
    @synchronized(self) {
        NSString* selectorString = NSStringFromSelector(callback);
        [self.deferredCallbacks addObject:selectorString];
    }
}

- (void)flushDeferredCallbacks {
    while (self.deferredCallbacks.count > 0) {
        NSString* selectorString = [self.deferredCallbacks objectAtIndex:0];
        NSLog(@"performing deferred callback %@", selectorString);
        SEL callback = NSSelectorFromString(selectorString);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:callback];
#pragma clang diagnostic pop
        [self.deferredCallbacks removeObjectAtIndex:0];
    }
}

#pragma mark - OTDefaultAudioDevice overrides

- (BOOL)startRendering
{
    if (self.audioPlayer) {
        [self enqueueDeferredCallback:_cmd];
        return YES;
    } else {
        return [super startRendering];
    }
}

- (BOOL)stopRendering
{
    if (self.audioPlayer) {
        [self enqueueDeferredCallback:_cmd];
        return YES;
    } else {
        return [super stopRendering];
    }
}

- (BOOL)startCapture
{
    if (self.audioPlayer) {
        [self enqueueDeferredCallback:_cmd];
        return YES;
    } else {
        return [super startCapture];
    }
}

- (BOOL)stopCapture
{
    if (self.audioPlayer) {
        [self enqueueDeferredCallback:_cmd];
        return YES;
    } else {
        return [super stopCapture];
    }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag
{
    NSLog(@"audioPlayerDidFinishPlaying success=%d", flag);
    [self stopRingtone];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError * __nullable)error
{
    NSLog(@"audioPlayerDecodeErrorDidOccur %@", error);
    [self stopRingtone];
}


@end
