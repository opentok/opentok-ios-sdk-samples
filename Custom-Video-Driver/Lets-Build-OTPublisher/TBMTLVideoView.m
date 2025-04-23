//
//  OTGLKVideoRender.m
//  otkit-objc-libs
//
//  This class derived from WebRTC's RTCEAGLVideoView.m, license below.
//
//

/*
 * libjingle
 * Copyright 2014, Google Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice,
 *     this list of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice,
 *     this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 *  3. The name of the author may not be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 * EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "TBMTLVideoView.h"
#import "TBMTLVideoRenderer.h"
#import <libkern/OSAtomic.h>
#import <sys/utsname.h>

@interface TBMTLVideoView ()
- (BOOL)needsRendererUpdate;

@end

@implementation TBMTLVideoView {
    MTKView* _mtkView;
   // TBMTLVideoRenderer* _mlRenderer;
    OTVideoFrame* _videoFrame;
    int64_t _lastFrameTime;
    NSLock* _frameLock;
    BOOL _renderingEnabled;
    volatile int32_t _clearRenderer;
    __unsafe_unretained id<TBRendererDelegate> _delegate;
    int _viewWidth;
    int _viewHeight;
}

@synthesize delegate = _delegate;

#pragma mark - Object Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _frameLock = [[NSLock alloc] init];
        _renderingEnabled = YES;
        _clearRenderer = 0;
        
        _viewWidth = frame.size.width;
        _viewHeight = frame.size.height;
        
        // We need this to retain mirrong and other view properties
        // when the app is in background
        _mlRenderer = [[TBMTLVideoRenderer alloc] init];
        
        BOOL metalSetup = [self setupMTL];
        if(metalSetup == NO)
        {
            return nil;
        }
    
        // Listen to application state in order to stop rendering while in background and
        // resume in foreground
        NSNotificationCenter* notificationCenter =
        [NSNotificationCenter defaultCenter];
        [notificationCenter
         addObserver:self
         selector:@selector(willResignActive)
         name:UIApplicationWillResignActiveNotification
         object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(didBecomeActive)
                                   name:UIApplicationDidBecomeActiveNotification
                                 object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_mtkView removeFromSuperview];
    
    _mtkView = nil;
    _mlRenderer = nil;
    [_frameLock lock];
    _videoFrame = nil;
    [_frameLock unlock];
    _frameLock = nil;
}

#pragma mark - Private Methods

- (void)didBecomeActive {
   if (_renderingEnabled)
   {
    	_mtkView.paused = NO;
   }
}

- (void)willResignActive {
    _mtkView.paused = YES;
}

- (BOOL)setupMTL {
    
    if (_mtkView == nil)
    {
        _mtkView = [[MTKView alloc] initWithFrame:CGRectZero];
        _mtkView.delegate = self;
        _mtkView.paused = ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground);

        [self addSubview:_mtkView];
    }
    
    return [_mlRenderer addRenderingDestination:_mtkView];
}

- (BOOL)needsRendererUpdate {
    return (_mlRenderer.lastFrameTime != _lastFrameTime && _renderingEnabled) ||
        _clearRenderer;
}


#pragma mark - Public

- (void)setScalesToFit:(BOOL)scalesToFit {
    [_mlRenderer setScalesToFit:scalesToFit];
}

- (BOOL)scalesToFit {
    return _mlRenderer.scalesToFit;
}

- (BOOL)mirroring {
    
    return _mlRenderer.mirroring;
}

- (void)setMirroring:(BOOL)mirroring {
    [_mlRenderer setMirroring:mirroring];
}

- (BOOL)renderingEnabled {
    return _renderingEnabled;
}

- (void)setRenderingEnabled:(BOOL)renderingEnabled {
     _renderingEnabled = renderingEnabled;
    if (_renderingEnabled)
    {
        OSAtomicTestAndClear(1, &_clearRenderer);
        _mtkView.paused = false;
    }
}

- (void)clearRenderBuffer {
	OSAtomicTestAndSet(1, &_clearRenderer);
}

#pragma mark - UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    _mtkView.autoResizeDrawable = YES;
    _mtkView.frame = self.bounds;
    _mtkView.autoResizeDrawable = NO;
    @synchronized (self) {
        _viewWidth = _mtkView.frame.size.width;
        _viewHeight = _mtkView.frame.size.height;
    }
}

- (void)getVideoViewSize:(int *)width height:(int *)height {
    @synchronized (self) {
        *width = _viewWidth;
        *height = _viewHeight;
    }
}

#pragma mark - OTVideoRender

- (void)renderVideoFrame:(OTVideoFrame*)frame {
    assert(OTPixelFormatI420 == frame.format.pixelFormat);
    
    [_frameLock lock];
    _videoFrame = nil;
    _videoFrame = frame;
    _lastFrameTime = frame.timestamp.value;
    [_frameLock unlock];
    
    if ([_delegate respondsToSelector:@selector(renderer:didReceiveFrame:)]) {
        [_delegate renderer:self didReceiveFrame:frame];
    }
    
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}

#pragma mark - MTKViewDelegate

// This method is called when the MTKView's content is dirty and needs to be
// redrawn. This occurs on main thread.
- (void)drawInMTKView:(nonnull MTKView *)view  {
    if (OSAtomicTestAndClear(1, &_clearRenderer)) {
        [_mlRenderer clearFrame];
        _mtkView.paused = true;
        return;
    }
    OTVideoFrame * frame = nil;
    [_frameLock lock];
    if (_videoFrame) {
        frame = _videoFrame;
        _videoFrame = nil;
    }
    [_frameLock unlock];
    if (frame) {
        // The renderer will draw the frame to the framebuffer corresponding to
        // the one used by |view|.
        [_mlRenderer drawFrame:frame viewSize:view.frame.size];
        frame = nil;
    }
}

@end

