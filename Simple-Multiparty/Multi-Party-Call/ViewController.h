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

@interface ViewController : UIViewController <OTSessionDelegate, OTPublisherDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate> {
    
}
@property (strong, nonatomic) IBOutlet UIScrollView *videoContainerView;
@property (strong, nonatomic) IBOutlet UIView *bottomOverlayView;
@property (strong, nonatomic) IBOutlet UIView *topOverlayView;
@property (retain, nonatomic) IBOutlet UIButton *cameraToggleButton;
@property (retain, nonatomic) IBOutlet UIButton *audioPubUnpubButton;
@property (retain, nonatomic) IBOutlet UILabel *userNameLabel;
@property (retain, nonatomic) NSTimer *overlayTimer;
@property (retain, nonatomic) IBOutlet UIButton *audioSubUnsubButton;
@property (retain, nonatomic) IBOutlet UIButton *endCallButton;
@property (retain, nonatomic) IBOutlet UIView *micSeparator;
@property (retain, nonatomic) IBOutlet UIView *cameraSeparator;
@property (retain, nonatomic) IBOutlet UIView *archiveOverlay;
@property (retain, nonatomic) IBOutlet UILabel *archiveStatusLbl;
@property (retain, nonatomic) IBOutlet UIImageView *archiveStatusImgView;
@property (retain, nonatomic) IBOutlet UIImageView *rightArrowImgView;
@property (retain, nonatomic) IBOutlet UIImageView *leftArrowImgView;
@property (retain, nonatomic) IBOutlet UIImageView *archiveStatusImgView2;


- (IBAction)toggleAudioSubscribe:(id)sender;
- (IBAction)toggleCameraPosition:(id)sender;
- (IBAction)toggleAudioPublish:(id)sender;
- (IBAction)endCallAction:(UIButton *)button;
@end