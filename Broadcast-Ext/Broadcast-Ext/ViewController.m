//
//  ViewController.m
//  Hello-World
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>

@implementation ViewController
RPSystemBroadcastPickerView *_broadcastPickerView;

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (@available(iOS 12.0, *)) {
        _broadcastPickerView = [[RPSystemBroadcastPickerView alloc] initWithFrame:
                                CGRectMake(0, 0, 50, 50)];
        _broadcastPickerView.preferredExtension = @"com.tokbox.Broadcast-Extension-Sample.OpenTok-Live";
        _broadcastPickerView.center = self.view.center;
    } else {
        // Fallback on earlier versions
    }
    
    
    [self.view addSubview:_broadcastPickerView];
    
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate {
    return UIUserInterfaceIdiomPhone != [[UIDevice currentDevice] userInterfaceIdiom];
}

@end
