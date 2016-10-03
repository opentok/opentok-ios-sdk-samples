//
//  TBAudioLevelMeter.m
//  TestAudioMeter
//
//  Created by Sridhar on 02/06/14.
//  Copyright (c) 2014 Tokbox. All rights reserved.
//

#import "TBAudioLevelMeter.h"

@interface TBAudioLevelMeter ()
{
    NSTimer *_updateTimer;
}
@end

@implementation TBAudioLevelMeter

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
    }
    return self;
}

-(void)layoutSubviews
{
    // align audio level meter to top right corner
    CGRect frame = self.frame;
    frame.origin.x = self.superview.frame.size.width - frame.size.width/2;
    frame.origin.y = -frame.size.height/2;
    self.frame = frame;
}

- (void)setLevel:(float)level
{
    _level = level;
    [self setNeedsDisplay];
}

- (UIView *)hitTest1:(CGPoint)point withEvent:(UIEvent *)event
{
    UIView *hitView = [super hitTest:point withEvent:event];
    
    // If the hitView is THIS view, return nil and allow hitTest:withEvent: to
    // continue traversing the hierarchy to find the underlying view.
    if (hitView == self) {
        return self.toucesPassToView;
    }
    // Else return the hitView (as it could be one of this view's buttons):
    return hitView;
}

#define   DEGREES_TO_RADIANS(degrees)  ((3.14159265359 * degrees)/ 180)
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //black background
    UIColor *blackColor = [UIColor blackColor];
    CGContextSetFillColorWithColor(context, [blackColor CGColor]);
    
    float maxRadius = ((float)self.frame.size.width / 2.0f - 0.5);
    float radius = maxRadius ;
    
    CGContextBeginPath(context);
    CGContextAddArc(context, self.frame.size.width/2, self.frame.size.height/2,
                    radius, DEGREES_TO_RADIANS(0), DEGREES_TO_RADIANS(360), NO);
    CGContextClosePath(context);
    CGContextFillPath(context);
    
    // Green circle 
    UIColor *greenColor = [UIColor colorWithRed:121.0f/255.0f
                                          green:166.0f/255.0f
                                           blue:51/255.0f
                                          alpha:1.f];
    CGContextSetFillColorWithColor(context, [greenColor CGColor]);
    
    maxRadius = ((float)self.frame.size.width / 2.0f - 0.5);
    radius = maxRadius * _level;
    
    CGContextBeginPath(context);
    CGContextAddArc(context, self.frame.size.width/2, self.frame.size.height/2,
                    radius, DEGREES_TO_RADIANS(0), DEGREES_TO_RADIANS(360), NO);
    CGContextClosePath(context);
    CGContextFillPath(context);
}

- (NSInteger)tag
{
    return 999;
}
@end
