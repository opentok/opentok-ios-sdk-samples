//
//  OTOverlayButton.m
//  Overlay-Graphics
//
//  Copyright (c) 2014 Tokbox, Inc. All rights reserved.
//

#import "TBExampleOverlayButton.h"
#import "TBExampleOverlayView.h"

#define OT_OVERLAY_DEFAULT_BUTTON_SIZE 48

@implementation TBExampleOverlayButton
{
    TBExampleOverlayButtonType _type;
    
    UIImage* _imgButtonStateUp;
    UIImage* _imgButtonStateDown;
    UIImage* _imgButtonStateSelected;
}

@synthesize type     = _type,
            delegate = _delegate;


- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    //clear the context
    CGContextClearRect(ctx, rect);
    
    //background gradient
    if (_type != TBExampleOverlayButtonTypeVolumeButton) {
        
        CGRect gradientRect = CGRectMake(1, rect.origin.y, rect.size.width,
                                         rect.size.height);

        CGGradientRef gradient;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

        size_t num_location = 4;
        
        CGFloat locations[4] = { 0.0, 0.47, 0.50, 1.0 };
        
        CGFloat downState[16] = { 
            0.0, 0.0, 0.0, 0.07,
            0.0, 0.0, 0.0, 0.07,
            1.0, 1.0, 1.0, 0.05,
            1.0, 1.0, 1.0, 0.3
        };

        CGFloat upState[16] = { 
            1.0, 1.0, 1.0, 0.3,
            1.0, 1.0, 1.0, 0.05,
            0.0, 0.0, 0.0, 0.07,
            0.0, 0.0, 0.0, 0.07
        };
        
        if (_type == TBExampleOverlayButtonTypeMuteButton && self.selected) {
            gradient = CGGradientCreateWithColorComponents(colorSpace,
                                                           downState,
                                                           locations,
                                                           num_location);
        } else {
            gradient = CGGradientCreateWithColorComponents(colorSpace,
                                                           upState,
                                                           locations,
                                                           num_location);
        }
        
        CGPoint startPoint = CGPointMake(CGRectGetMidX(gradientRect),
                                         CGRectGetMinY(gradientRect));
        CGPoint endPoint = CGPointMake(CGRectGetMidX(gradientRect),
                                       CGRectGetMaxY(gradientRect));
        
        CGContextSaveGState(ctx);
        CGContextAddRect(ctx, gradientRect);
        CGContextClip(ctx);
        CGContextDrawLinearGradient(ctx, gradient, startPoint, endPoint, 0);
        CGContextRestoreGState(ctx);
        
        CGGradientRelease(gradient);
        CGColorSpaceRelease(colorSpace);
    }
    
    if (_type != TBExampleOverlayButtonTypeVolumeButton) {
    
        CGContextSetLineWidth(ctx, 1.0f);
        CGContextSetShouldAntialias(ctx, NO);
        
        //draw the one pixel black line left of button
        CGContextSetRGBStrokeColor(ctx, 0.0, 0.0, 0.0, 0.28);
        CGContextMoveToPoint(ctx, 0.5, 0.5);
        CGContextAddLineToPoint(ctx, 0.5, self.frame.size.height+0.5);
        
        CGContextStrokePath(ctx);
        
        //draw the one pixel white line left of button
        CGContextSetRGBStrokeColor(ctx, 1.0, 1.0 ,1.0, 0.11);
        CGContextMoveToPoint(ctx, 1.5, 1.5);
        CGContextAddLineToPoint(ctx, 1.5, self.frame.size.height+0.5);
        
        CGContextStrokePath(ctx);
        
        //draw the one pixel white line above the button
        CGContextSetRGBStrokeColor(ctx, 1.0, 1.0 ,1.0, 0.19);
        CGContextMoveToPoint(ctx, 1.5, 0.5);
        CGContextAddLineToPoint(ctx, self.frame.size.width+0.5, 0.5);
        
        CGContextStrokePath(ctx);
    }
    
    if (self.highlighted) {       
                
        CGGradientRef glossGradient;
        CGColorSpaceRef rgbColorspace;
        
        size_t num_locations = 2;
        
        CGFloat locations[2] = { 0.0, 1.0 };
        
        CGFloat components[8] = { 
                                  1.0, 1.0, 1.0, 0.45,  // Start color
                                  1.0, 1.0, 1.0, 0.00   // End color
                                }; 
        
        rgbColorspace = CGColorSpaceCreateDeviceRGB();
        glossGradient = CGGradientCreateWithColorComponents(rgbColorspace,
                                                            components,
                                                            locations,
                                                            num_locations);
        
        CGPoint startPoint, endPoint;
        startPoint.x = CGRectGetMidX(self.bounds);
        startPoint.y = CGRectGetMidY(self.bounds);
        endPoint.x = CGRectGetMidX(self.bounds);
        endPoint.y = CGRectGetMidY(self.bounds);
        
        float startRadius = 0;
        float endRadius = MIN(CGRectGetWidth(self.bounds),
                              CGRectGetHeight(self.bounds))/2;
        
        CGContextDrawRadialGradient(ctx, glossGradient, startPoint,
                                    startRadius, endPoint, endRadius,
                                    kCGGradientDrawsBeforeStartLocation);
        
        CGGradientRelease(glossGradient);
        CGColorSpaceRelease(rgbColorspace);
        
    }
}

- (id)initWithFrame:(CGRect)frame
  overlayButtonType:(TBExampleOverlayButtonType)buttonType
           delegate:(id<TBExampleOverlayButtonDelegate>)delegate        
{
    
    if (self = [super initWithFrame:frame]) {

        _type = buttonType;
        _delegate = delegate;
        
        [[self imageView] setBackgroundColor:[UIColor clearColor]];
        
        switch (buttonType) {
            case TBExampleOverlayButtonTypeMuteButton:
                _imgButtonStateUp =
                [[UIImage imageNamed:@"unmuteSubscriber.png"] retain];
                _imgButtonStateSelected =
                [[UIImage imageNamed:@"muteSubscriber.png"] retain];
                
                break;
                
            case TBExampleOverlayButtonTypeSwitchCameraButton:
                _imgButtonStateUp =
                [[UIImage imageNamed:@"swapCamera.png"] retain];
                
                break;
                
            case TBExampleOverlayButtonTypeVolumeButton:
                _imgButtonStateUp =
                [[UIImage imageNamed:@"unmutePublisher.png"] retain];
                _imgButtonStateSelected =
                [[UIImage imageNamed:@"mutePublisher.png"] retain];

                break;
                
            default:
                break;
        }        
        
        //button images
        if (_imgButtonStateUp)
            [self setImage:_imgButtonStateUp forState:UIControlStateNormal];
        
        if (_imgButtonStateDown)
            [self setImage:_imgButtonStateDown
                  forState:UIControlStateHighlighted];
        else if (_imgButtonStateUp)
            [self setImage:_imgButtonStateUp
                  forState:UIControlStateHighlighted];
                
        if (_imgButtonStateSelected) {
            [self setImage:_imgButtonStateSelected
                  forState:UIControlStateSelected];
            [self setImage:_imgButtonStateSelected
                  forState:(UIControlStateHighlighted|UIControlStateSelected)];
        }

        [self setAdjustsImageWhenHighlighted:NO];
        [self setShowsTouchWhenHighlighted:NO];
        
        //button events
        [self addTarget:self 
                 action:@selector(overlayButtonWasTouched:withEvent:)
       forControlEvents:UIControlEventAllEvents];
        
        [self addTarget:self 
                 action:@selector(overlayButtonWasSelected:withEvent:)
       forControlEvents:UIControlEventTouchUpInside];
        
    }
        
    return self;
}

- (void)dealloc {
    [_imgButtonStateUp release];
    [_imgButtonStateSelected release];
    [_imgButtonStateDown release];
    [super dealloc];
}

- (void)overlayButtonWasTouched:(TBExampleOverlayButton*)button
                      withEvent:(UIEvent*)event
{
    //draw our gradient for button pushdown
    [self setNeedsDisplay];
}

- (void)overlayButtonWasSelected:(TBExampleOverlayButton*)button
                       withEvent:(UIEvent*)event
{    
    switch (button.type) {
        case TBExampleOverlayButtonTypeMuteButton:
            
            [button setSelected:!button.selected];
            
            break;
            
        case TBExampleOverlayButtonTypeSwitchCameraButton:
            
            break;
            
        case TBExampleOverlayButtonTypeVolumeButton:
            
            [button setSelected:!button.selected];
            
            break;
            
        default:
            break;
    }
    
    if ([_delegate respondsToSelector:@selector(overlayButtonWasSelected:)]) {
        [_delegate overlayButtonWasSelected:button];
    }
    
    //prevents the button from remaining highlighted under some circumstances:
    //double taps, dragging after tapping, etc were causing weird behavior
    [button setHighlighted:NO];
}

@end
