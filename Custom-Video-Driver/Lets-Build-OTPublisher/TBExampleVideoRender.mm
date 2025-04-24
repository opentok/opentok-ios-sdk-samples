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

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include <TargetConditionals.h>
#import <libkern/OSAtomic.h>
#import <sys/utsname.h>
#import "TBExampleVideoRender.h"

#define MTL_STRINGIFY(s) @ #s

/**
 * Protocol defining ability to render RTCVideoFrame in Metal enabled views.
 */
@protocol RTCMTLRenderer<NSObject>
/**
 * Method to be implemented to perform actual rendering of the provided frame.
 *
 * @param frame The frame to be rendered.
 */
- (void)drawFrame:(OTVideoFrame *)frame viewSize:(CGSize)viewSize;
/**
 * Sets the provided view as rendering destination if possible.
 *
 * If not possible method returns NO and callers of the method are responisble for performing
 * cleanups.
 */
#if TARGET_OS_IOS
- (BOOL)addRenderingDestination:(__kindof UIView *)view;
#else
- (BOOL)addRenderingDestination:(__kindof NSView *)view;
#endif
@end

/**
 * Implementation of RTCMTLRenderer protocol for rendering native nv12 video frames.
 */
NS_AVAILABLE(10_11, 9_0)
@interface VGMTLVideoRenderer : UIView <RTCMTLRenderer>
{
    
}
@property (readonly) int64_t lastFrameTime;

@property (nonatomic) BOOL scalesToFit;
@property (nonatomic) BOOL mirroring;
@property (nonatomic, assign) id<TBRendererDelegate> delegate;

- (BOOL)clearFrame;

- (nullable id<MTLDevice>)currentMetalDevice;
- (NSString *)shaderSource;
- (BOOL)setupTexturesForFrame:(nonnull OTVideoFrame *)frame viewSize:(CGSize)viewSize;
- (void)uploadTexturesToRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder;

@end

static NSString *const shaderSource = MTL_STRINGIFY(
    using namespace metal;
    typedef struct {
      packed_float2 position;
      packed_float2 texcoord;
    } Vertex;
    typedef struct {
      float4 position[[position]];
      float2 texcoord;
    } Varyings;
    vertex Varyings vertexPassthrough(constant Vertex * verticies[[buffer(0)]],
                                      unsigned int vid[[vertex_id]]) {
      Varyings out;
      constant Vertex &v = verticies[vid];
      out.position = float4(float2(v.position), 0.0, 1.0);
      out.texcoord = v.texcoord;
      return out;
    }
    fragment half4 fragmentColorConversion(
        Varyings in[[stage_in]], texture2d<float, access::sample> textureY[[texture(0)]],
        texture2d<float, access::sample> textureU[[texture(1)]],
        texture2d<float, access::sample> textureV[[texture(2)]]) {
      constexpr sampler s(address::clamp_to_edge, filter::linear);
      float y;
      float u;
      float v;
      float r;
      float g;
      float b;
      // Conversion for YUV to rgb from http://www.fourcc.org/fccyvrgb.php
      y = textureY.sample(s, in.texcoord).r;
      u = textureU.sample(s, in.texcoord).r;
      v = textureV.sample(s, in.texcoord).r;
      u = u - 0.5;
      v = v - 0.5;
      r = y + 1.403 * v;
      g = y - 0.344 * u - 0.714 * v;
      b = y + 1.770 * u;
      float4 out = float4(r, g, b, 1.0);
      return half4(out);
    });

// As defined in shaderSource.
static NSString *const vertexFunctionName = @"vertexPassthrough";
static NSString *const fragmentFunctionName = @"fragmentColorConversion";
static NSString *const pipelineDescriptorLabel = @"RTCPipeline";
static NSString *const commandBufferLabel = @"RTCCommandBuffer";
static NSString *const renderEncoderLabel = @"RTCEncoder";
static NSString *const renderEncoderDebugGroup = @"RTCDrawFrame";
// Computes the texture coordinates given rotation and cropping.
static inline void getCubeVertexData(int cropX,
                                     int cropY,
                                     int cropWidth,
                                     int cropHeight,
                                     size_t frameWidth,
                                     size_t frameHeight,
                                     float *buffer,
                                     bool isMirroring,
                                     bool scalesToFit,
                                     CGSize viewportSize) {
    // The computed values are the adjusted texture coordinates, in [0..1].
    // For the left and top, 0.0 means no cropping and e.g. 0.2 means we're skipping 20% of the
    // left/top edge.
    // For the right and bottom, 1.0 means no cropping and e.g. 0.8 means we're skipping 20% of the
    // right/bottom edge (i.e. render up to 80% of the width/height).
    float cropLeft = cropX / (float)frameWidth;
    float cropRight = (cropX + cropWidth) / (float)frameWidth;
    float cropTop = cropY / (float)frameHeight;
    float cropBottom = (cropY + cropHeight) / (float)frameHeight;
    // These arrays map the view coordinates to texture coordinates, taking cropping and rotation
    // into account. The first two columns are view coordinates, the last two are texture coordinates.
    
    float imageRatio =
    (float)frameWidth / (float)frameHeight;
    float viewportRatio =
    (float)viewportSize.width / (float)viewportSize.height;
    
    float scaleX = 1.0;
    float scaleY = 1.0;
    BOOL constrainWide = NO;
    
    if (scalesToFit) {
        constrainWide = imageRatio > viewportRatio;
    } else {
        constrainWide = imageRatio < viewportRatio;
    }
    
    if (constrainWide) {
        scaleY = viewportRatio / imageRatio;
    } else {
        scaleX = imageRatio / viewportRatio;
    }
    
    if (isMirroring) {
        scaleX *= -1;
    }
    
    float values[16] = {
        static_cast<float>(-1.0 * scaleX), static_cast<float>(-1.0 * scaleY), cropLeft, cropBottom,
        static_cast<float>(1.0 * scaleX), static_cast<float>(-1.0 * scaleY), cropRight, cropBottom,
        static_cast<float>(-1.0 * scaleX),  static_cast<float>(1.0 * scaleY), cropLeft, cropTop,
        static_cast<float>(1.0 * scaleX),  static_cast<float>(1.0 * scaleY), cropRight, cropTop};
    
    memcpy(buffer, &values, sizeof(values));
}

// The max number of command buffers in flight (submitted to GPU).
// For now setting it up to 1.
// In future we might use triple buffering method if it improves performance.
static const NSInteger kMaxInflightBuffers = 1;

@implementation VGMTLVideoRenderer {
    __kindof MTKView *_view;
    // Controller.
    dispatch_semaphore_t _inflight_semaphore;
    // Renderer.
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLLibrary> _defaultLibrary;
    id<MTLRenderPipelineState> _pipelineState;
    // Buffers.
    id<MTLBuffer> _vertexBuffer;
    
    id<MTLTexture> _yTexture;
    id<MTLTexture> _uTexture;
    id<MTLTexture> _vTexture;
    MTLTextureDescriptor *_descriptor;
    MTLTextureDescriptor *_chromaDescriptor;
    int _width;
    int _height;
    int _chromaWidth;
    int _chromaHeight;
    
    // Values affecting the vertex buffer. Stored for comparison to avoid unnecessary recreation.
    int _oldFrameWidth;
    int _oldFrameHeight;
    int _oldCropWidth;
    int _oldCropHeight;
    int _oldCropX;
    int _oldCropY;
    BOOL _oldScalesToFit;
    BOOL _oldMirroring;
    
    CGSize _viewSizeOld;
}
- (instancetype)init {
    if (self = [super init]) {
        // _offset of 0 is equal to rotation of 0.
        _inflight_semaphore = dispatch_semaphore_create(kMaxInflightBuffers);
    }
    return self;
}
- (BOOL)addRenderingDestination:(__kindof MTKView *)view {
    return [self setupWithView:view];
}
#pragma mark - Private
- (BOOL)setupWithView:(__kindof MTKView *)view {
    BOOL success = NO;
    if ([self setupMetal]) {
        _view = view;
        _viewSizeOld = view.frame.size;
        view.device = _device;
        view.preferredFramesPerSecond = 30;
        view.autoResizeDrawable = NO;
        [self loadAssets];
        float vertexBufferArray[16] = {0};
        _vertexBuffer = [_device newBufferWithBytes:vertexBufferArray
                                             length:sizeof(vertexBufferArray)
                                            options:MTLResourceCPUCacheModeWriteCombined];
        success = YES;
    }
    return success;
}
#pragma mark - Inheritance
- (id<MTLDevice>)currentMetalDevice {
    return _device;
}
- (NSString *)shaderSource {
    // RTC_NOTREACHED() << "Virtual method not implemented in subclass.";
    return shaderSource;
}

- (void)getWidth:(nonnull int *)width
          height:(nonnull int *)height
       cropWidth:(nonnull int *)cropWidth
      cropHeight:(nonnull int *)cropHeight
           cropX:(nonnull int *)cropX
           cropY:(nonnull int *)cropY
     scalesToFit:(nonnull bool *)scalesToFit
       mirroring:(nonnull bool *)mirroring
         ofFrame:(nonnull OTVideoFrame *)frame {
    *width = frame.format.imageWidth;
    *height = frame.format.imageHeight;
    *cropWidth = frame.format.imageWidth;
    *cropHeight = frame.format.imageHeight;
    *cropX = 0;
    *cropY = 0;
    *scalesToFit = self.scalesToFit;
    *mirroring = self.mirroring;
}

- (void)uploadTexturesToRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    // RTC_NOTREACHED() << "Virtual method not implemented in subclass.";
    [renderEncoder setFragmentTexture:_yTexture atIndex:0];
    [renderEncoder setFragmentTexture:_uTexture atIndex:1];
    [renderEncoder setFragmentTexture:_vTexture atIndex:2];
}
- (BOOL)setupTexturesForFrame:(OTVideoFrame *)frame
                     viewSize:(CGSize)viewSize {
    // Apply rotation override if set.

    int frameWidth, frameHeight, cropWidth, cropHeight, cropX, cropY;
    bool scalesToFit, mirroring;
    [self getWidth:&frameWidth
            height:&frameHeight
         cropWidth:&cropWidth
        cropHeight:&cropHeight
             cropX:&cropX
             cropY:&cropY
       scalesToFit:&scalesToFit
         mirroring:&mirroring
           ofFrame:frame];
    // Recompute the texture cropping and recreate vertexBuffer if necessary.
    if (cropX != _oldCropX || cropY != _oldCropY || cropWidth != _oldCropWidth ||
        cropHeight != _oldCropHeight  || frameWidth != _oldFrameWidth ||
        frameHeight != _oldFrameHeight || scalesToFit != _oldScalesToFit ||
        mirroring != _oldMirroring ||
        CGSizeEqualToSize(_viewSizeOld, viewSize) == false) {
        getCubeVertexData(cropX,
                          cropY,
                          cropWidth,
                          cropHeight,
                          frameWidth,
                          frameHeight,
                          (float *)_vertexBuffer.contents,
                          self.mirroring,
                          self.scalesToFit,
                          _view.frame.size
                          );
        _oldCropX = cropX;
        _oldCropY = cropY;
        _oldCropWidth = cropWidth;
        _oldCropHeight = cropHeight;
        _oldFrameWidth = frameWidth;
        _oldFrameHeight = frameHeight;
        _oldScalesToFit = scalesToFit;
        _oldMirroring = mirroring;
    }

    id<MTLDevice> device = [self currentMetalDevice];
    if (!device) {
        return NO;
    }

    //id<RTCI420Buffer> buffer = [frame.buffer toI420];
    // Luma (y) texture.
    if (!_descriptor || _width != frame.format.imageWidth
                         || _height != frame.format.imageHeight ||
                         CGSizeEqualToSize(_viewSizeOld, viewSize) == false) {
        _width = frame.format.imageWidth;
        _height = frame.format.imageHeight;
        _viewSizeOld = viewSize;
        _descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                                         width:_width
                                                                        height:_height
                                                                     mipmapped:NO];
        _descriptor.usage = MTLTextureUsageShaderRead;
        _yTexture = [device newTextureWithDescriptor:_descriptor];
    }
    // Chroma (u,v) textures
    [_yTexture replaceRegion:MTLRegionMake2D(0, 0, _width, _height)
                 mipmapLevel:0
                   withBytes:[frame.planes pointerAtIndex:0]
                 bytesPerRow:[frame getPlaneStride:0]];
    if (!_chromaDescriptor ||
        (_chromaWidth != ((frame.format.imageWidth + 1) / 2) ||
         _chromaHeight != ((frame.format.imageHeight + 1) / 2)))
    {
        _chromaWidth = (frame.format.imageWidth + 1) / 2;
        _chromaHeight = (frame.format.imageHeight + 1) / 2;
        _chromaDescriptor =
        [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                           width:_chromaWidth
                                                          height:_chromaHeight
                                                       mipmapped:NO];
        _chromaDescriptor.usage = MTLTextureUsageShaderRead;
        _uTexture = [device newTextureWithDescriptor:_chromaDescriptor];
        _vTexture = [device newTextureWithDescriptor:_chromaDescriptor];
    }
    [_uTexture replaceRegion:MTLRegionMake2D(0, 0, _chromaWidth, _chromaHeight)
                 mipmapLevel:0
                   withBytes:[frame.planes pointerAtIndex:1]
                 bytesPerRow:[frame getPlaneStride:1]];
    [_vTexture replaceRegion:MTLRegionMake2D(0, 0, _chromaWidth, _chromaHeight)
                 mipmapLevel:0
                   withBytes:[frame.planes pointerAtIndex:2]
                 bytesPerRow:[frame getPlaneStride:2]];
    return (_uTexture != nil) && (_yTexture != nil) && (_vTexture != nil);
    
}

#pragma mark - GPU methods
- (BOOL)setupMetal {
    // Set the view to use the default device.
    _device = MTLCreateSystemDefaultDevice();
    if (!_device) {
        return NO;
    }
    // Create a new command queue.
    _commandQueue = [_device newCommandQueue];
    // Load metal library from source.
    NSError *libraryError = nil;
    NSString *shaderSource = [self shaderSource];
    id<MTLLibrary> sourceLibrary =
    [_device newLibraryWithSource:shaderSource options:NULL error:&libraryError];
    
    // Ignore warnings
    if (libraryError && libraryError.code != MTLLibraryErrorCompileWarning) {
        return NO;
    }
    if (!sourceLibrary) {
        return NO;
    }
    _defaultLibrary = sourceLibrary;
    return YES;
}
- (void)setupView:(__kindof MTKView *)view {
    view.device = _device;
    view.preferredFramesPerSecond = 30;
    view.autoResizeDrawable = NO;
    // We need to keep reference to the view as it's needed down the rendering pipeline.
    _view = view;
}
- (void)loadAssets {
    id<MTLFunction> vertexFunction = [_defaultLibrary newFunctionWithName:vertexFunctionName];
    id<MTLFunction> fragmentFunction = [_defaultLibrary newFunctionWithName:fragmentFunctionName];
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.label = pipelineDescriptorLabel;
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;
    pipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatInvalid;
    NSError *error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_pipelineState) {
        NSLog(@"Metal: Failed to create pipeline state. %@", error);
    }
}

- (void)render {
    //guard
    if (CGSizeEqualToSize(_view.frame.size, CGSizeZero)) {
        return;
    }
    // Wait until the inflight (currently sent to GPU) command buffer
    // has completed the GPU work.
    dispatch_semaphore_wait(_inflight_semaphore, DISPATCH_TIME_FOREVER);
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    commandBuffer.label = commandBufferLabel;
    __block dispatch_semaphore_t block_semaphore = _inflight_semaphore;
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull) {
        // GPU work completed.
        dispatch_semaphore_signal(block_semaphore);
    }];
    
    MTLRenderPassDescriptor *renderPassDescriptor = _view.currentRenderPassDescriptor;
    // This is to avoid compilation error for Metal in Simualtor
    #if (TARGET_IPHONE_SIMULATOR)
    if (renderPassDescriptor) {  // Valid drawable.
    #else
    if (renderPassDescriptor && _view.currentDrawable.texture) {  // Valid drawable.
    #endif
        id<MTLRenderCommandEncoder> renderEncoder =
        [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        renderEncoder.label = renderEncoderLabel;
        // Set context state.
        [renderEncoder pushDebugGroup:renderEncoderDebugGroup];
        [renderEncoder setRenderPipelineState:_pipelineState];
        [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
        [self uploadTexturesToRenderEncoder:renderEncoder];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                          vertexStart:0
                          vertexCount:4
                        instanceCount:1];
        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:_view.currentDrawable];
    }
    // CPU work is completed, GPU work can be started.
    [commandBuffer commit];
}

- (BOOL)clearFrame {
    @autoreleasepool {
        // Wait until the inflight (currently sent to GPU) command buffer
        // has completed the GPU work.
        dispatch_semaphore_wait(_inflight_semaphore, DISPATCH_TIME_FOREVER);
        id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
        commandBuffer.label = commandBufferLabel;
        __block dispatch_semaphore_t block_semaphore = _inflight_semaphore;
        [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull) {
            // GPU work completed.
            dispatch_semaphore_signal(block_semaphore);
        }];
        MTLRenderPassDescriptor *renderPassDescriptor = _view.currentRenderPassDescriptor;
        if (renderPassDescriptor) {  // Valid drawable.
            id<MTLRenderCommandEncoder> renderEncoder =
            [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
            renderEncoder.label = renderEncoderLabel;
            // Set context state.
            [renderEncoder pushDebugGroup:renderEncoderDebugGroup];
            [renderEncoder setRenderPipelineState:_pipelineState];
            [renderEncoder popDebugGroup];
            [renderEncoder endEncoding];
            [commandBuffer presentDrawable:_view.currentDrawable];
        }
        // CPU work is completed, GPU work can be started.
        [commandBuffer commit];
        return YES;
    }
}

#pragma mark - OTMTLVideoRenderer
- (void)drawFrame:(OTVideoFrame *)frame viewSize:(CGSize)viewSize {
    @autoreleasepool {
        if ([self setupTexturesForFrame:frame viewSize:viewSize]) {
            _lastFrameTime = frame.timestamp.value;
            [self render];
        }
    }
}
@end

@interface TBExampleVideoRender ()
- (BOOL)needsRendererUpdate;

@end

@implementation TBExampleVideoRender {
    MTKView* _mtkView;
    VGMTLVideoRenderer* _mlRenderer;
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
        _mlRenderer = [[VGMTLVideoRenderer alloc] init];
        
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

