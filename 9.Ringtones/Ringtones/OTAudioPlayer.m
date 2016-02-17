//
//  OTAudioPlayer.m
//  Ringtones
//
//  Created by Charley Robinson on 2/16/16.
//  Copyright © 2016 TokBox, Inc. All rights reserved.
//

#import "OTAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>

@interface OTAudioPlayer() <AVAudioPlayerDelegate>

@end

@implementation OTAudioPlayer {
    AVAudioPlayer* _audioPlayer;
    NSMutableArray* _deferredCallbacks;
}

-(instancetype)init
{
    self = [super init];
    if (self) {
        _deferredCallbacks = [NSMutableArray new];
    }
    return self;
}

- (void)playRingtoneFromURL:(NSURL*)url
{
    NSError* error = nil;
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url
                                                          error:&error];
    [_audioPlayer setDelegate:self];
    [_audioPlayer play];
}

- (void)stopRingtone {
    [_audioPlayer stop];
    _audioPlayer = nil;
    [self flushDeferredCallbacks];
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
        return [super startCapture];
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
    _audioPlayer = nil;
    [self flushDeferredCallbacks];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError * __nullable)error
{
    NSLog(@"audioPlayerDecodeErrorDidOccur %@", error);
    _audioPlayer = nil;
    [self flushDeferredCallbacks];
}


@end
