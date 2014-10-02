//
//  TBScreenPublisher.h
//  Screen-Sharing
//
//  Copyright (c) 2014 TokBox Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenTok/OpenTok.h>

@interface TBScreenPublisher : OTPublisherKit
@property(readonly) UIView* view;
@end
