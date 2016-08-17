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

@end
