//
//  ViewController.h
//  Multi-Party-Call
//
//  Created by Sridhar on 07/04/14.
//  Copyright (c) 2014 Tokbox. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Opentok/Opentok.h>
#import <QuartzCore/QuartzCore.h>
#import "TBVoiceViewCell.h"

@interface TBViewController : UIViewController <OTSessionDelegate,
OTPublisherDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate,
UIScrollViewDelegate,
OTPublisherKitAudioLevelDelegate> {
    
}
@property (strong, nonatomic) IBOutlet UIScrollView *videoContainerView;
@property (strong, nonatomic) IBOutlet UIView *bottomOverlayView;
@property (retain, nonatomic) IBOutlet UIButton *endCallButton;
@property (retain, nonatomic) IBOutlet UIView *archiveOverlay;
@property (retain, nonatomic) IBOutlet UILabel *archiveStatusLbl;
@property (retain, nonatomic) IBOutlet UIImageView *archiveStatusImgView;
@property (retain, nonatomic)  NSString *publisherName;
@property (retain, nonatomic) IBOutlet UIActivityIndicatorView *spinningWheel;
@property (retain, nonatomic) IBOutlet UITableView *tableView;
@property (retain, nonatomic) IBOutlet UIView *publisherView;
@property (retain, nonatomic) IBOutlet UIImageView *publisherProfileImgVIew;
@property (retain, nonatomic) IBOutlet UILabel *publisherNameLbl;
@property (retain, nonatomic) IBOutlet UIView *publisherMicContainerView;
@property (retain, nonatomic) IBOutlet UIButton *publisherMicButton;
@property (retain, nonatomic) TBAudioLevelMeter *publisherAudioLevelMeter;

- (IBAction)toggleAudioPublish:(id)sender;
- (IBAction)endCallAction:(UIButton *)button;
@end