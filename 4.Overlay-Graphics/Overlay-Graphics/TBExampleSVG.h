//
//  OTSVG.h
//  Overlay-Graphics
//
//  Copyright (c) 2014 Tokbox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>

@class UIView, UIImage;

@interface TBExampleSVGHelper : NSObject

+ (UIImage*)imageFromSVGString:(NSString*)source;
+ (UIImage*)imageFromSVGString:(NSString *)source size:(CGSize)size;
+ (UIView*)viewFromSVGString:(NSString*)source;

@end

@interface TBExampleSVGIcons : NSObject

+ (NSString*)swapCamera;
+ (NSString*)microphone;
+ (NSString*)audioOnlyInactive;
+ (NSString*)audioOnlyActive;
+ (NSString*)muteSubscriber;
+ (NSString*)mutePublisher;
+ (NSString*)unmuteSubscriber;
+ (NSString*)unmutePublisher;
+ (NSString*)highCongestion;
+ (NSString*)midCongestion;

@end