//
//  OTDefaultAudioDevice+Volume.m
//  External-Audio-Device
//
//  Created by Sridhar on 08/03/16.
//  Copyright © 2016 TokBox Inc. All rights reserved.
//

#import "OTDefaultAudioDeviceWithVolumeControl.h"

/* private API declares: for internal use only. */
@interface OTDefaultAudioDevice()

- (BOOL)setupAudioUnit:(AudioUnit *)voice_unit playout:(BOOL)isPlayout;
- (void)disposePlayoutUnit;
- (void)checkAndPrintError:(OSStatus)error function:(NSString *)function;
- (BOOL)setPlayOutRenderCallback:(AudioUnit)unit;

@end

@implementation OTDefaultAudioDeviceWithVolumeControl
{
  
}

- (BOOL)setupAudioUnit:(AudioUnit *)voice_unit playout:(BOOL)isPlayout
{
    BOOL result = [super setupAudioUnit:voice_unit playout:isPlayout];
    return result;
}

- (void)disposePlayoutUnit
{
    [super disposePlayoutUnit];
}

-(void)setPlayoutVolume:(float)value;
{

}

@end
