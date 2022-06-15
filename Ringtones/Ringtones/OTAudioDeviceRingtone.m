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
    NSMutableArray* _deferredCallbacks;
    BOOL _vibratesWithRingtone;
    NSTimer* _vibrateTimer;
}

@synthesize vibratesWithRingtone = _vibratesWithRingtone;

-(instancetype)init
{
    self = [super init];
    if (self) {
        _deferredCallbacks = [NSMutableArray new];
    }
   
    return self;
}

// Only called from [self startCapture] where  acquiring audio is serialized for pub and ringtone
- (void)playRingtoneFromURL:(NSURL*)url
{
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
    
    // Allow background playback, only if the default driver hasn't already
    // started running. Setting the category while the audio session is
    // configured for voice chat (PlayAndRecord) will interrupt recording and
    // cause problems if a publisher is running.
    if (!self.isCapturing && !self.isRendering) {
        AVAudioSession* audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayback
                            error:nil];
        AVAudioSessionPortDescription *routePort = audioSession.currentRoute.outputs.firstObject;
        NSString *portType = routePort.portType;
        if ([portType isEqualToString:@"Receiver"]) {
               [audioSession  overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error];
        } else {
               [audioSession  overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:&error];
        }

        [audioSession setActive:YES error:nil];
    }
    
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

- (void)stopRingtone {
    // Stop Audio
    [_audioPlayer stop];
    _audioPlayer = nil;
    
    // Stop vibration
    [_vibrateTimer invalidate];
    _vibrateTimer = nil;
    
    // Allow deferred audio callback calls to flow
    [self flushDeferredCallbacks];
}

- (void)buzz:(NSTimer*)timer {
    if (_vibratesWithRingtone) {
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
        [_deferredCallbacks addObject:selectorString];
    }
}

- (void)flushDeferredCallbacks {
    while (_deferredCallbacks.count > 0) {
        NSString* selectorString = [_deferredCallbacks objectAtIndex:0];
        NSLog(@"performing deferred callback %@", selectorString);
        SEL callback = NSSelectorFromString(selectorString);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:callback];
#pragma clang diagnostic pop
        [_deferredCallbacks removeObjectAtIndex:0];
    }
}

#pragma mark - OTDefaultAudioDevice overrides

- (BOOL)startRendering
{
    if (_audioPlayer) {
        [self enqueueDeferredCallback:_cmd];
        return YES;
    } else {
        return [super startRendering];
    }
}

- (BOOL)stopRendering
{
    if (_audioPlayer) {
        [self enqueueDeferredCallback:_cmd];
        return YES;
    } else {
        return [super stopRendering];
    }
}

- (BOOL)startCapture
{
    if (_audioPlayer) {
        [self enqueueDeferredCallback:_cmd];
        return YES;
    } else {
        BOOL ret = [super startCapture];
        [self playRingtoneFromURL:self.ringtoneURL];
        return ret;
    }
}

- (BOOL)stopCapture
{
    if (_audioPlayer) {
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
