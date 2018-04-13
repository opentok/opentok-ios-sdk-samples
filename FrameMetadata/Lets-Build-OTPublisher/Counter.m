//
//  Counter.m
//  Custom-Video-Driver
//
//  Created by Lucas Huang on 4/12/18.
//  Copyright © 2018 TokBox, Inc. All rights reserved.
//

#import "Counter.h"

@interface Counter()
@property (nonatomic, readwrite) NSUInteger count;
@end

@implementation Counter

+ (instancetype)sharedManager {
    static Counter *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[Counter alloc] init];
    });
    return sharedMyManager;
}

- (void)increase {
    self.count += 1;
}

@end
