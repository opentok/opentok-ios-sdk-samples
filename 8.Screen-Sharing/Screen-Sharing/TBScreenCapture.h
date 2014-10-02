//
//  TBScreenCapture.h
//  Screen-Sharing
//
//  Copyright (c) 2014 TokBox Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

@protocol OTVideoCapture;

@interface TBScreenCapture : NSObject <OTVideoCapture>

@property(atomic, assign) id<OTVideoCaptureConsumer>videoCaptureConsumer;
@property(nonatomic, strong) UIView* view;

@end
