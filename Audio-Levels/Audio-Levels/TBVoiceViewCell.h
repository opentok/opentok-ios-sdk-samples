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
{
    
}
- (IBAction)toggleSubscribeAudio:(id)sender;

@property (retain, nonatomic) TBAudioLevelMeter *audioLevelMeter;
@property (retain, nonatomic) IBOutlet UIImageView *profileImgView;
@property (retain, nonatomic) IBOutlet UILabel *name;
@property (retain, nonatomic) IBOutlet UIView *spkrContainerView;
@property (retain, nonatomic) IBOutlet UIButton *spkrButtonView;
@property (assign, nonatomic)  OTSubscriber *subscriber;
@end
