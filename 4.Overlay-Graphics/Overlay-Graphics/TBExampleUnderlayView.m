//
//  OTUnderlayView.m
//  Overlay-Graphics
//
//  Copyright (c) 2014 TokBox. All rights reserved.
//

#import "TBExampleUnderlayView.h"

#define SILHOUETTE_OFFSET 0.0
#define SILHOUETTE_SIZE 0.75

@implementation TBExampleUnderlayView
{    
    UIImageView* _audioOnlyActiveView;
    UIImageView* _audioOnlyInactiveView;
    UIImage* _audioOnlyActive;
    UIImage* _audioOnlyInactive;
}

@synthesize audioActive;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
       
        self.backgroundColor = [UIColor colorWithHue:0 saturation:0 brightness:.13 alpha:1];
        self.clipsToBounds = YES;
        
        _audioOnlyActive = [[UIImage imageNamed:@"audioOnlyActive.png"] retain];
        _audioOnlyActiveView = [[UIImageView alloc] initWithImage:_audioOnlyActive];
        _audioOnlyActiveView.backgroundColor = [UIColor clearColor];
        
        _audioOnlyInactive = [[UIImage imageNamed:@"audioOnlyInactive.png"] retain];
        _audioOnlyInactiveView = [[UIImageView alloc] initWithImage:_audioOnlyInactive];
        _audioOnlyInactiveView.backgroundColor = [UIColor clearColor];
        _audioOnlyInactiveView.hidden = YES;
        audioActive = YES;
        
        [self addSubview:_audioOnlyActiveView];
        [self addSubview:_audioOnlyInactiveView];
        
    }
    return self;
}

- (void)setAudioActive:(BOOL)isActive {
    if (isActive == audioActive) {
        return;
    }
    audioActive = isActive;
    
    [_audioOnlyActiveView setHidden:!isActive];
    [_audioOnlyInactiveView setHidden:isActive];
    
    [self setNeedsLayout];
}

- (void)dealloc {
    [_audioOnlyActiveView release];
    [_audioOnlyInactiveView release];
    [_audioOnlyActive release];
    [_audioOnlyInactive release];
    [super dealloc];
}

- (void)layoutSubviews
{
    // Layout Audio-Only views
    float ratio = (float)(_audioOnlyActiveView.image.size.width/_audioOnlyActiveView.image.size.height);
    float sW = (self.frame.size.height * SILHOUETTE_SIZE) * ratio;
        
    float sH = self.frame.size.height * SILHOUETTE_SIZE;
    float sYOffset = self.frame.size.height * SILHOUETTE_OFFSET;
    _audioOnlyActiveView.frame = CGRectMake(0, 0, sW, sH);
    _audioOnlyActiveView.center = CGPointMake(self.frame.size.width/2, self.frame.size.height/2 + sYOffset);

    _audioOnlyInactiveView.frame = _audioOnlyActiveView.frame;
    _audioOnlyInactiveView.center = _audioOnlyActiveView.center;
}

@end