//
//  OTKBasicVideoCapturer.h
//  Getting Started
//
//  Created by rpc on 03/03/15.
//  Copyright (c) 2015 OpenTok. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

@interface OTKBasicVideoCapturerCamera : NSObject<OTVideoCapture>

- (id)initWithPreset:(NSString *)preset andDesiredFrameRate:(NSUInteger)frameRate;
@end
