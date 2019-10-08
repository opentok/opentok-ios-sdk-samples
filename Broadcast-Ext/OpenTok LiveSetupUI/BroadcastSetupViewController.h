//
//  BroadcastSetupViewController.h
//  OpenTok LiveSetupUI
//
//  Created by Sridhar Bollam on 8/4/19.
//  Copyright © 2019 TokBox, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ReplayKit/ReplayKit.h>

@interface BroadcastSetupViewController : UIViewController <UITextViewDelegate>
- (IBAction)startSharing:(id)sender;
- (IBAction)cancel:(id)sender;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *startButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;

@end
