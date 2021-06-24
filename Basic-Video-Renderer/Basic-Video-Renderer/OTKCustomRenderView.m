//
//  OTKCustomRenderView.m
//  Getting Started
//
//  Created by rpc on 06/03/15.
//  Copyright (c) 2015 OpenTok. All rights reserved.
//

#import "OTKCustomRenderView.h"

@implementation OTKCustomRenderView {
    CGImageRef _img;
}

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _renderQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        _img = NULL;
    }
    return self;
}

- (void)renderVideoFrame:(OTVideoFrame *)frame
{
    __block OTVideoFrame *frameToRender = frame;
    dispatch_sync(self.renderQueue, ^{
        if (_img != NULL) {
            CGImageRelease(_img);
            _img = NULL;
        }
        
        size_t bufferSize = frameToRender.format.imageHeight * frameToRender.format.imageWidth * 3;
        uint8_t *buffer = malloc(bufferSize);
        
        uint8_t *yplane = [frameToRender.planes pointerAtIndex:0];
        
        for (int i = 0; i < frameToRender.format.imageHeight; i++) {
            for (int j = 0; j < frameToRender.format.imageWidth; j++) {
                int starting = (i * frameToRender.format.imageWidth * 3) + (j * 3);
                uint8_t yvalue = yplane[(i * frameToRender.format.imageWidth) + j];
                // If in a RGB image we copy the same Y value for R, G and B
                // we will obtain a Black & White image
                buffer[starting] = yvalue;
                buffer[starting+1] = yvalue;
                buffer[starting+2] = yvalue;
            }
        }
        
        CGDataProviderRef imgProvider = CGDataProviderCreateWithData(NULL,
                                                                     buffer,
                                                                     bufferSize,
                                                                     release_frame);
        
        _img = CGImageCreate(frameToRender.format.imageWidth,
                             frameToRender.format.imageHeight,
                             8,
                             24,
                             3 * frameToRender.format.imageWidth,
                             CGColorSpaceCreateDeviceRGB(),
                             kCGBitmapByteOrder32Big | kCGImageAlphaNone,
                             imgProvider,
                             NULL,
                             false,
                             kCGRenderingIntentDefault);
        
        
        CGDataProviderRelease(imgProvider);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNeedsDisplay];
        });
    });
}

void release_frame(void *info, const void *data, size_t size)
{
    free((void *)data);
}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    __block CGImageRef img = NULL;
    dispatch_sync(self.renderQueue, ^{
        img = CGImageCreateCopy(_img);
    });
    if (img != NULL) {
        CGContextDrawImage(context,self.frame,img);
        CGImageRelease(img);
    }
}

- (void)drawRect:(CGRect)rect
{
}
@end
