//
//  OTKBasicVideoRender.h
//  Getting Started
//
//  Created by rpc on 06/03/15.
//  Copyright (c) 2015 OpenTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

@interface OTKBasicVideoRender : NSObject<OTVideoRender>

@property (nonatomic, strong) UIView *renderView;

@end
