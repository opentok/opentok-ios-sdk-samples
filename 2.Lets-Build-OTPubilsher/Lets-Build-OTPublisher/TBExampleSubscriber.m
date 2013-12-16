//
//  TBSubscriber.m
//  Lets-Build-OTPublisher
//
//  Created by Charley Robinson on 12/16/13.
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "TBExampleSubscriber.h"
#import "TBExampleVideoRender.h"

@implementation TBExampleSubscriber {
    TBExampleVideoRender* _myVideoRender;
}

@synthesize view = _myVideoRender;

- (id)initWithStream:(OTStream *)stream
            delegate:(id<OTSubscriberKitDelegate>)delegate
{
    self = [super initWithStream:stream delegate:delegate];
    if (self) {
        _myVideoRender =
        [[TBExampleVideoRender alloc] initWithFrame:CGRectMake(0,0,1,1)];
        [self setVideoRender:_myVideoRender];
    }
    return self;
}

- (void)dealloc {
    [self setVideoRender:nil];
    [_myVideoRender release];
    _myVideoRender = nil;
    [super dealloc];
}

@end
