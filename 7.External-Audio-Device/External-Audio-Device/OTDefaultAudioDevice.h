//
//  OTAudioDeviceIOSDefault.h
//
//  Copyright (c) 2014 TokBox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

#define kMixerInputBusCount 2
#define kOutputBus 0
#define kInputBus 1

#define AUDIO_DEVICE_HEADSET     @"AudioSessionManagerDevice_Headset"
#define AUDIO_DEVICE_BLUETOOTH   @"AudioSessionManagerDevice_Bluetooth"
#define AUDIO_DEVICE_SPEAKER     @"AudioSessionManagerDevice_Speaker"

@interface OTDefaultAudioDevice : NSObject <OTAudioDevice>
{
    AudioStreamBasicDescription stream_format;
}

/**
 * Audio device lifecycle should live for the duration of the process, and
 * needs to be set before OTSession is initialized.
 *
 * It is not recommended to initialize unique audio device instances.
 */
+ (instancetype)sharedInstance;

/** 
 * Override the audio unit preferred component subtype. This can be used to
 * force RemoteIO to be used instead of VPIO (the default). It is recommended
 * to set this prior to instantiating any publisher/subscriber; changes will
 * not take effect until after the next audio unit setup call.
 */
@property (nonatomic) uint32_t preferredAudioComponentSubtype;

@end
