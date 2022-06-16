//
//  OTAudioPlayer.h
//  Ringtones
//
//  Created by Charley Robinson on 2/16/16.
//  Copyright © 2016 TokBox, Inc. All rights reserved.
//


#import "OTDefaultAudioDevice.h"

@interface OTAudioDeviceRingtone : OTDefaultAudioDevice

@property (nonatomic) BOOL vibratesWithRingtone;

- (instancetype) init __attribute__((unavailable("init not available, useinitWithRingtone:")));
- (instancetype)initWithRingtone:(NSURL *)url;

// Immediately stops the ringtone and allows OpenTok audio calls to flow
- (void)stopRingtone;

@end
