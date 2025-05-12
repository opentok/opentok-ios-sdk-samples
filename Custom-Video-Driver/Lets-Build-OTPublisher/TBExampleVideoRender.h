//
//  OTGLKVideoRender.h
//  otkit-objc-libs
//
//  Created by Charley Robinson on 5/23/14.
//
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <OpenTok/OpenTok.h>

@protocol TBRendererDelegate;

/**
 * Implementation of RTCMTLRenderer protocol for rendering native nv12 video frames.
 */
NS_AVAILABLE(10_11, 9_0)
@interface TBExampleVideoRender : UIView <MTKViewDelegate, OTVideoRender>
{
    
}
@property (readonly) int64_t lastFrameTime;

@property (nonatomic) BOOL scalesToFit;
@property (nonatomic) BOOL mirroring;
@property (nonatomic, assign) id<TBRendererDelegate> delegate;

- (BOOL)clearRenderBuffer;


@end

/**
 * Used to notify the owner of this renderer that frames are being received.
 * For our example, we'll use this to wire a notification to the subscriber's
 * delegate that video has arrived.
 */
@protocol TBRendererDelegate <NSObject>

- (void)renderer:(TBExampleVideoRender*)renderer
 didReceiveFrame:(OTVideoFrame*)frame;

@end
