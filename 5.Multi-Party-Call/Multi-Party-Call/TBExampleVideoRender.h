//
//  TBExampleVideoRender.h
//
//  Copyright (c) 2013 Tokbox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <OpenTok/OpenTok.h>

/**
 * An example implementation for OTVideoRender. This class will render YUV
 * pixel buffers to the UIView hierarchy. We rely on libyuv to provide YUV to
 * RGB conversion prior to loading the buffer into OpenGL.
 */

@interface TBExampleVideoRender : UIView <OTVideoRender>

/**
 * Renders a video frame to the view.
 * Fufills the contract of OTVideoRender.
 */
- (void)renderVideoFrame:(OTVideoFrame*)frame;

/**
 * Sets a block to fetch a (retained!) UIImage of the most recent frame.
 */
- (void)getSnapshotWithBlock:(void (^)(UIImage* snapshot))block;

@end
