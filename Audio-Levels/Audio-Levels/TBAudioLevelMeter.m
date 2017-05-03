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

- (void)setLevel:(float)level
{
    _level = level;
    [self setNeedsDisplay];
}

//-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
//{
//    NSLog(@"Point inside called");
//    return YES;
//}

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
    UIColor *greenColor = [UIColor colorWithRed:152.0f/255.0f
                                          green:206.0f/255.0f
                                           blue:0/255.0f
                                          alpha:0.5f];
    CGContextSetFillColorWithColor(context, [greenColor CGColor]);
    
    float maxRadius = ((float)self.frame.size.width / 2.0f - 0.5);
    float radius = maxRadius * _level;
    
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
