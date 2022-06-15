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
@property (nonatomic)  NSURL * ringtoneURL;

// Immediately stops the ringtone and allows OpenTok audio calls to flow
- (void)stopRingtone;

@end
