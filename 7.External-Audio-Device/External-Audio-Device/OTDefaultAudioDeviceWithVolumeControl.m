//
//  OTDefaultAudioDevice+Volume.m
//  External-Audio-Device
//
//  Created by Sridhar on 08/03/16.
//  Copyright © 2016 TokBox Inc. All rights reserved.
//

#import "OTDefaultAudioDeviceWithVolumeControl.h"

@interface OTDefaultAudioDevice(Private)
- (BOOL)setupAudioUnit:(AudioUnit *)voice_unit playout:(BOOL)isPlayout;
- (void)disposePlayoutUnit;
- (void)checkAndPrintError:(OSStatus)error function:(NSString *)function;
@end

@implementation OTDefaultAudioDeviceWithVolumeControl
{
    AudioUnit mixerUnit;
}

- (BOOL)setupAudioUnit:(AudioUnit *)voice_unit playout:(BOOL)isPlayout
{
    BOOL result = [super setupAudioUnit:voice_unit playout:isPlayout];
    
    if (isPlayout)
    {
        AudioComponentDescription mixerDescription = {
            .componentType = kAudioUnitType_Mixer,
            .componentSubType = kAudioUnitSubType_MultiChannelMixer,
            .componentManufacturer = kAudioUnitManufacturer_Apple
        };
        
        AudioComponent mixerComp = AudioComponentFindNext(NULL, &mixerDescription);
        
        AudioComponentInstanceNew(mixerComp, &mixerUnit);
        
        OSStatus status = 0;
        status = AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input, kOutputBus,
                                     &stream_format, sizeof (stream_format));
        if (status != noErr) {
            [self checkAndPrintError:status function:@"setupAudioUnit VolumeControl"];
        }
        
        [self setPlayOutRenderCallback:mixerUnit];
        
        //disable voip render callback (is this really needed ?)
        AURenderCallbackStruct render_callback;
        render_callback.inputProc = NULL;;
        render_callback.inputProcRefCon = (__bridge void *)(self);
        AudioUnitSetProperty(*voice_unit, kAudioUnitProperty_SetRenderCallback,
                                               kAudioUnitScope_Input, kOutputBus, &render_callback,
                                               sizeof(render_callback));

        AudioUnitConnection	connection;
        UInt32				size;
        size = sizeof(connection);
        
        connection.sourceOutputNumber = 0;
        connection.destInputNumber    = 0;
        connection.sourceAudioUnit = mixerUnit;
        status = AudioUnitSetProperty(*voice_unit,  kAudioUnitProperty_MakeConnection,
                                     kAudioUnitScope_Input, kOutputBus, &connection, size);
        if (status != noErr) {
            [self checkAndPrintError:status function:@"setupAudioUnit VolumeControl"];
        }

        // Need this when screen lock present.
        UInt32 maxFPS = 4096;
        AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                             &maxFPS, sizeof(maxFPS));
        
        status = AudioUnitInitialize(mixerUnit);
        if (status != noErr) {
            [self checkAndPrintError:status function:@"setupAudioUnit VolumeControl"];
        }
    }
    return result;
}

- (void)disposePlayoutUnit
{
    if (mixerUnit) {
        AudioUnitUninitialize(mixerUnit);
        AudioComponentInstanceDispose(mixerUnit);
        mixerUnit = NULL;
    }
    [super disposePlayoutUnit];
}

-(void)setPlayoutVolume:(float)value;
{
    if(mixerUnit)
    {
        AudioUnitSetParameter(mixerUnit, kMultiChannelMixerParam_Volume,
                              kAudioUnitScope_Input, kOutputBus, value, 0);
    }
}

@end
