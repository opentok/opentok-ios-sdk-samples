//
//  Counter.h
//  Custom-Video-Driver
//
//  Created by Lucas Huang on 4/12/18.
//  Copyright © 2018 TokBox, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Counter : NSObject

@property (nonatomic, readonly) NSUInteger count;

+ (instancetype)sharedManager;

- (void)increase;

@end
