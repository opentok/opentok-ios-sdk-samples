//
//  OTUnderlayView.h
//  Overlay-Graphics
//
//  Copyright (c) 2014 TokBox. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    TBExampleUnderlayViewTypeSubscriber = 0,
    TBExampleUnderlayViewTypePublisher  = 1
} TBExampleUnderlayViewType;

@interface TBExampleUnderlayView : UIView

@property (nonatomic) BOOL audioActive;

- (id)initWithFrame:(CGRect)frame;

@end
