//
//  OTAudioPlayer.h
//  Ringtones
//
//  Created by Charley Robinson on 2/16/16.
//  Copyright © 2016 TokBox, Inc. All rights reserved.
//

#import "OTDefaultAudioDevice.h"

@interface OTAudioDeviceRingtone : OTDefaultAudioDevice

// Initializes an audio player and immediately starts playback.
// As long as the ringtone is playing, OpenTok audio calls will be deferred.
- (void)playRingtoneFromURL:(NSURL*)url;

// Immediately stops the rington and allows OpenTok audio calls to flow
- (void)stopRingtone;

@end
