//
//  OTKCustomRenderView.h
//  Getting Started
//
//  Created by rpc on 06/03/15.
//  Copyright (c) 2015 OpenTok. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <OpenTok/OpenTok.h>

@interface OTKCustomRenderView : UIView

@property (strong, nonatomic) dispatch_queue_t renderQueue;

- (void)renderVideoFrame:(OTVideoFrame *)frame;

@end
