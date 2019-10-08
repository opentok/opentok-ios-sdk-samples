//
//  ViewController.m
//  Hello-World
//
//  Copyright (c) 2013 TokBox, Inc. All rights reserved.
//

#import "ViewController.h"
#import <OpenTok/OpenTok.h>

@implementation ViewController
#if !(TARGET_OS_SIMULATOR)
API_AVAILABLE(ios(12.0))
RPSystemBroadcastPickerView *_broadcastPickerView;
#endif

#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    #if !(TARGET_OS_SIMULATOR)
    if (@available(iOS 12.0, *)) {
        _broadcastPickerView = [[RPSystemBroadcastPickerView alloc] initWithFrame:
                                CGRectMake(0, 0, 50, 50)];
        _broadcastPickerView.preferredExtension = @"com.tokbox.Broadcast-Ext-Sample.OpenTok-Live";
        _broadcastPickerView.center = self.view.center;
    } else {
        // Fallback on earlier versions
    }

    if (@available(iOS 12.0, *)) {
        [self.view addSubview:_broadcastPickerView];
    }
    #endif
    
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (BOOL)shouldAutorotate {
    return UIUserInterfaceIdiomPhone != [[UIDevice currentDevice] userInterfaceIdiom];
}

@end
