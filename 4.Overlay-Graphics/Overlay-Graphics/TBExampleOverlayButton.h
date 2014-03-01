//
//  OTOverlayButton.h
//  Overlay-Graphics
//
//  Copyright (c) 2014 Tokbox, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol TBExampleOverlayButtonDelegate;

typedef enum {
    TBExampleOverlayButtonTypeMuteButton,
    TBExampleOverlayButtonTypeVolumeButton,
    TBExampleOverlayButtonTypeSwitchCameraButton
} TBExampleOverlayButtonType;

@interface TBExampleOverlayButton : UIButton

@property (nonatomic) TBExampleOverlayButtonType type;
@property (nonatomic, assign) id<TBExampleOverlayButtonDelegate> delegate;

- (id)initWithFrame:(CGRect)frame
  overlayButtonType:(TBExampleOverlayButtonType)buttonType
           delegate:(id<TBExampleOverlayButtonDelegate>)delegate;

@end

@protocol TBExampleOverlayButtonDelegate <NSObject>

- (void)overlayButtonWasSelected:(TBExampleOverlayButton*)button;

@end
