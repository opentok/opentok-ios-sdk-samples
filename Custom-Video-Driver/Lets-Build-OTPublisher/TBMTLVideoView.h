//
//  OTGLKVideoRender.h
//  otkit-objc-libs
//
//  Created by Charley Robinson on 5/23/14.
//
//

#import <UIKit/UIKit.h>
#import "TBMTLVideoRenderer.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface TBMTLVideoView : UIView <MTKViewDelegate, OTVideoRender>
@property (nonatomic, assign) id<TBRendererDelegate> delegate;
@property (nonatomic)   TBMTLVideoRenderer* mlRenderer;
@end


