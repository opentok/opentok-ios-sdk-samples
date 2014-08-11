//
//  TBVoiceViewCell.m
//  OpenTokRTC
//
//  Created by Sridhar on 28/07/14.
//  Copyright (c) 2014 Song Zheng. All rights reserved.
//

#import "TBVoiceViewCell.h"

@implementation TBVoiceViewCell

- (void)awakeFromNib
{
    // Initialization code
    // audio level meter
    _audioLevelMeter = [[TBAudioLevelMeter alloc]
                                          initWithFrame:CGRectZero];
    _audioLevelMeter.opaque = false;
    _audioLevelMeter.userInteractionEnabled = NO;
    CGRect frame = _spkrButtonView.frame;
    _audioLevelMeter.frame = frame;
    [_spkrContainerView addSubview:_audioLevelMeter];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)subscriber:(OTSubscriberKit *)subscriber
 audioLevelUpdated:(float)audioLevel{
    float db = 20 * log10(audioLevel);
    float floor = -40;
    float level = 0;
    if (db > floor) {
        level = db + abs(floor);
        level /= abs(floor);
    }
    self.audioLevelMeter.level = level;
}

- (IBAction)toggleSubscribeAudio:(id)sender {
    if (self.subscriber.subscribeToAudio == YES) {
        self.audioLevelMeter.level = 0.0f;
        self.name.alpha = .75f;
        self.subscriber.audioLevelDelegate = nil;
		self.subscriber.subscribeToAudio = NO;
		self.spkrButtonView.selected = YES;
	} else {
        self.name.alpha = 1;
        self.subscriber.audioLevelDelegate = self;
		self.subscriber.subscribeToAudio = YES;
		self.spkrButtonView.selected = NO;
	}
}
@end
