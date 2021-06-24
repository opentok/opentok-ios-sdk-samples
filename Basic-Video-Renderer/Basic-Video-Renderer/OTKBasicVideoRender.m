//
//  OTKBasicVideoRender.m
//  Getting Started
//
//  Created by rpc on 06/03/15.
//  Copyright (c) 2015 OpenTok. All rights reserved.
//

#import "OTKBasicVideoRender.h"
#import "OTKCustomRenderView.h"

@implementation OTKBasicVideoRender

- (id)init
{
    self = [super init];
    if (self) {
        _renderView = [[OTKCustomRenderView alloc] initWithFrame:CGRectZero];
    }
    return self;
}

- (void)renderVideoFrame:(OTVideoFrame*) frame
{
    [(OTKCustomRenderView*)self.renderView renderVideoFrame:frame];
}

@end
