//
//  OTDefaultAudioDevice+Volume.h
//  External-Audio-Device
//
//  Created by Sridhar on 08/03/16.
//  Copyright © 2016 TokBox Inc. All rights reserved.
//

#import "OTDefaultAudioDevice.h"

@interface OTDefaultAudioDeviceWithVolumeControl : OTDefaultAudioDevice
{
    
}
// value range - 0 (min) and 1 (max)
-(void)setPlayoutVolume:(float)value;
@end
