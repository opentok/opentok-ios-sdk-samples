//
//  TBVoiceViewCell.h
//  OpenTokRTC
//
//  Created by Sridhar on 28/07/14.
//  Copyright (c) 2014 Song Zheng. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TBAudioLevelMeter.h"
#import <Opentok/Opentok.h>

@interface TBVoiceViewCell : UITableViewCell <OTSubscriberKitAudioLevelDelegate>

- (IBAction)toggleSubscribeAudio:(id)sender;

@property (nonatomic) TBAudioLevelMeter *audioLevelMeter;
@property (nonatomic) IBOutlet UIImageView *profileImgView;
@property (nonatomic) IBOutlet UILabel *name;
@property (nonatomic) IBOutlet UIView *spkrContainerView;
@property (nonatomic) IBOutlet UIButton *spkrButtonView;
@property (nonatomic)  OTSubscriber *subscriber;
@end
