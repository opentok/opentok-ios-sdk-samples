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

#import "TBExampleVideoRender.h"
#import <libkern/OSAtomic.h>
#import <OpenGLES/ES2/gl.h>

@interface TBDisplayLinkProxy : NSObject
- (id)initWithGLKView:(GLKView*)view delegate:(TBExampleVideoRender*)delegate;
- (void)displayLinkDidFire:(CADisplayLink*)displayLink;
@end

@interface TBEAGLVideoRenderer : NSObject

@property (readonly) int64_t lastFrameTime;

- (instancetype)initWithContext:(EAGLContext*)context;

// Draws |frame| onto the currently bound OpenGL framebuffer. |setupGL| must be
// called before this function will succeed.
- (BOOL)drawFrame:(OTVideoFrame*)frame withViewport:(CGRect)viewport;

// Clears the render buffer, discarding any image data that was being displayed.
- (BOOL)clearFrame;

// The following methods are used to manage OpenGL resources. On iOS
// applications should release resources when placed in background for use in
// the foreground application. In fact, attempting to call OpenGLES commands
// while in background will result in application termination.

// Sets up the OpenGL state needed for rendering.
- (void)setupGL;
// Tears down the OpenGL state created by |setupGL|.
- (void)teardownGL;

@property (nonatomic, assign) BOOL mirroring;

@end

@interface TBExampleVideoRender ()
- (BOOL)needsRendererUpdate;
@end

@implementation TBExampleVideoRender {
    CADisplayLink* _displayLink;
    TBDisplayLinkProxy* _displayLinkProxy;
    EAGLContext* _glContext;
    GLKView* _glkView;
    TBEAGLVideoRenderer* _glRenderer;
    OTVideoFrame* _videoFrame;
    int64_t _lastFrameTime;
    NSLock* _frameLock;
    BOOL _renderingEnabled;
    volatile int32_t _clearRenderer;
    id<TBRendererDelegate> _delegate;
}

@synthesize delegate = _delegate;

#pragma mark - Object Lifecycle

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _glContext =
        [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _glRenderer = [[TBEAGLVideoRenderer alloc] initWithContext:_glContext];
        
        _glkView = [[GLKView alloc] initWithFrame:CGRectZero
                                          context:_glContext];
        _glkView.drawableColorFormat = GLKViewDrawableColorFormatRGBA8888;
        _glkView.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
        _glkView.drawableStencilFormat = GLKViewDrawableStencilFormatNone;
        _glkView.drawableMultisample = GLKViewDrawableMultisampleNone;
        _glkView.delegate = self;
        _glkView.layer.masksToBounds = YES;
        [self addSubview:_glkView];
        
        _frameLock = [[NSLock alloc] init];
        _renderingEnabled = YES;
        _clearRenderer = 0;
        
        // Listen to application state in order to clean up OpenGL before app
        // goes away.
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
        _displayLinkProxy =
        [[TBDisplayLinkProxy alloc] initWithGLKView:_glkView delegate:self];
        
        _displayLink =
        [[CADisplayLink
          displayLinkWithTarget:_displayLinkProxy
          selector:@selector(displayLinkDidFire:)] retain];
        
        _displayLink.paused = YES;
        // Set to half of screen refresh, which should be 30fps.
        [_displayLink setFrameInterval:2];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                           forMode:NSRunLoopCommonModes];
        [self setupGL];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    UIApplicationState appState =
    [UIApplication sharedApplication].applicationState;
    if (appState == UIApplicationStateActive) {
        [self teardownGL];
    }
    [_glContext release];
    [_displayLink invalidate];
    [_displayLink release];
    [_displayLinkProxy release];
    [_glkView release];
    [_glRenderer release];
    [_frameLock lock];
    free([_videoFrame.planes pointerAtIndex:0]);
    [_videoFrame release];
    _videoFrame = nil;
    [_frameLock unlock];
    [_frameLock release];
    [super dealloc];
}


#pragma mark - Private Methods

- (void)setupGL {
    [_glRenderer setupGL];
    _displayLink.paused = NO;
}

- (void)teardownGL {
    _displayLink.paused = YES;
    [_glkView deleteDrawable];
    [_glRenderer teardownGL];
}

- (void)didBecomeActive {
    [self setupGL];
}

- (void)willResignActive {
    [self teardownGL];
}

+ (BOOL)videoFrame:(OTVideoFrame*)fromFrame
    canCopyToFrame:(OTVideoFrame*)toFrame
{
    if (fromFrame.format.imageWidth != toFrame.format.imageWidth) {
        return NO;
    }
    
    if (fromFrame.format.imageHeight != toFrame.format.imageHeight) {
        return NO;
    }
    
    return YES;
}

- (BOOL)needsRendererUpdate {
    return (_glRenderer.lastFrameTime != _lastFrameTime && _renderingEnabled) ||
    _clearRenderer;
}


#pragma mark - Public

- (BOOL)mirroring {
    return _glRenderer.mirroring;
}

- (void)setMirroring:(BOOL)mirroring {
    [_glRenderer setMirroring:mirroring];
}

- (BOOL)renderingEnabled {
    return _renderingEnabled;
}

- (void)setRenderingEnabled:(BOOL)renderingEnabled {
    _renderingEnabled = renderingEnabled;
}

- (void)clearRenderBuffer {
    OSAtomicTestAndSet(1, &_clearRenderer);
}

#pragma mark - UIView

- (void)layoutSubviews {
    [super layoutSubviews];
    _glkView.frame = self.bounds;
}


#pragma mark - OTVideoRender

- (void)renderVideoFrame:(OTVideoFrame*)frame {
    [_frameLock lock];
    assert(OTPixelFormatI420 == frame.format.pixelFormat);
    if (![TBExampleVideoRender videoFrame:frame canCopyToFrame:_videoFrame])
    {
        free([_videoFrame.planes pointerAtIndex:0]);
        [_videoFrame release];
        _videoFrame = [[OTVideoFrame alloc] initWithFormat:frame.format];
        void* frameData = malloc(frame.format.imageWidth *
                                 frame.format.imageHeight * 3 / 2);
        
        // TODO: clean this up, lots of assumptions being made here.
        // Y
        [_videoFrame.planes addPointer:frameData];
        // U
        [_videoFrame.planes addPointer:&(frameData[frame.format.imageHeight
                                                   * frame.format.imageWidth])];
        // V
        [_videoFrame.planes addPointer:&(frameData[frame.format.imageHeight *
                                                   frame.format.imageWidth *
                                                   5 / 4])];
    }
    
    memcpy([_videoFrame.planes pointerAtIndex:0],
           [frame.planes pointerAtIndex:0],
           frame.format.imageHeight * frame.format.imageWidth * 3 / 2);
    
    _videoFrame.timestamp = frame.timestamp;
    // Keep frame timestamp separately so we don't have to lock to access
    _lastFrameTime = frame.timestamp.value;
    [_frameLock unlock];
    
    if ([_delegate respondsToSelector:@selector(renderer:didReceiveFrame:)]) {
        [_delegate renderer:self didReceiveFrame:frame];
    }
}

#pragma mark - GLKViewDelegate

// This method is called when the GLKView's content is dirty and needs to be
// redrawn. This occurs on main thread.
- (void)glkView:(GLKView*)view drawInRect:(CGRect)rect {
    if (OSAtomicTestAndClear(1, &_clearRenderer)) {
        [_glRenderer clearFrame];
        return;
    }
    
    [_frameLock lock];
    if (_videoFrame) {
        // The renderer will draw the frame to the framebuffer corresponding to
        // the one used by |view|.
        [_glRenderer drawFrame:_videoFrame withViewport:view.frame];
    }
    [_frameLock unlock];
}

@end

#pragma mark - OTDisplayLinkProxy -

// We need this in a separate class, otherwise a circular retain keeps the owner
// from deallocating.
@implementation TBDisplayLinkProxy {
    // unretained, unsafe ivars
    GLKView* _glkView;
    TBExampleVideoRender* _delegate;
}

- (id)initWithGLKView:(GLKView*)view delegate:(TBExampleVideoRender*)delegate
{
    self = [super init];
    if (self) {
        _glkView = view;
        _delegate = delegate;
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
}

#pragma mark - DisplayLink delegate

// Frames are received on a separate thread, so we poll for current frame
// using a refresh rate proportional to screen refresh frequency. This occurs
// on the main thread.
- (void)displayLinkDidFire:(CADisplayLink*)displayLink {
    // Don't render if frame hasn't changed.
    // This tells the GLKView that it's dirty, which will then call the the
    // GLKViewDelegate method implemented above.
    if ([_delegate needsRendererUpdate]) {
        [_glkView setNeedsDisplay];
    }
}

@end


#pragma mark - OTEAGLVideoRenderer Implementation -

// TODO(tkchin): check and log openGL errors. Methods here return BOOLs in
// anticipation of that happening in the future.

// Convenience macro for writing shader code that converts a code snippet into
// a C string during the C preprocessor step.
#define RTC_STRINGIZE(...) #__VA_ARGS__

// Vertex shader doesn't do anything except pass coordinates through.
static const char kVertexShaderSource[] =
RTC_STRINGIZE(
              attribute vec2 position;
              attribute vec2 texcoord;
              varying vec2 v_texcoord;
              void main() {
                  gl_Position = vec4(position.x, position.y, 0.0, 1.0);
                  v_texcoord = texcoord;
              }
              );

// Fragment shader converts YUV values from input textures into a final RGB
// pixel. The conversion formula is from http://www.fourcc.org/fccyvrgb.php.
static const char kFragmentShaderSource[] =
RTC_STRINGIZE(
              precision highp float;
              varying vec2 v_texcoord;
              uniform lowp sampler2D s_textureY;
              uniform lowp sampler2D s_textureU;
              uniform lowp sampler2D s_textureV;
              void main() {
                  float y, u, v, r, g, b;
                  y = texture2D(s_textureY, v_texcoord).r;
                  u = texture2D(s_textureU, v_texcoord).r;
                  v = texture2D(s_textureV, v_texcoord).r;
                  u = u - 0.5;
                  v = v - 0.5;
                  r = y + 1.403 * v;
                  g = y - 0.344 * u - 0.714 * v;
                  b = y + 1.770 * u;
                  gl_FragColor = vec4(r, g, b, 1.0);
              }
              );

// Compiles a shader of the given |type| with GLSL source |source| and returns
// the shader handle or 0 on error.
static GLuint CreateShader(GLenum type, const GLchar* source) {
    GLuint shader = glCreateShader(type);
    if (!shader) {
        return 0;
    }
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint compileStatus = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compileStatus);
    if (compileStatus == GL_FALSE) {
        glDeleteShader(shader);
        shader = 0;
    }
    return shader;
}

// Links a shader program with the given vertex and fragment shaders and
// returns the program handle or 0 on error.
static GLuint CreateProgram(GLuint vertexShader, GLuint fragmentShader) {
    if (vertexShader == 0 || fragmentShader == 0) {
        return 0;
    }
    GLuint program = glCreateProgram();
    if (!program) {
        return 0;
    }
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);
    GLint linkStatus = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == GL_FALSE) {
        glDeleteProgram(program);
        program = 0;
    }
    return program;
}

// When modelview and projection matrices are identity (default) the world is
// contained in the square around origin with unit size 2. Drawing to these
// coordinates is equivalent to drawing to the entire screen. The texture is
// stretched over that square using texture coordinates (u, v) that range
// from (0, 0) to (1, 1) inclusive. Texture coordinates are flipped vertically
// here because the incoming frame has origin in upper left hand corner but
// OpenGL expects origin in bottom left corner.
//static const GLfloat gVertices[] = {
//    // X, Y, U, V.
//    -1, -1, 0, 1,  // Bottom left.
//    1,  -1, 1, 1,  // Bottom right.
//    1,  1,  1, 0,  // Top right.
//    -1, 1,  0, 0,  // Top left.
//};
// REFACTOR(Charley): Moving this matrix to the instance, where X,Y position
// coordinates can be modified to preserve the aspect ratio of the rendered
// frames. In case the view hierarchy is not performing this work.

// |kNumTextures| must not exceed 8, which is the limit in OpenGLES2. Two sets
// of 3 textures are used here, one for each of the Y, U and V planes. Having
// two sets alleviates CPU blockage in the event that the GPU is asked to render
// to a texture that is already in use.
static const GLsizei kNumTextureSets = 2;
static const GLsizei kNumTextures = 3 * kNumTextureSets;

@implementation TBEAGLVideoRenderer {
    EAGLContext* _context;
    BOOL _isInitialized;
    NSUInteger _currentTextureSet;
    // Handles for OpenGL constructs.
    GLuint _textures[kNumTextures];
    GLuint _program;
    GLuint _vertexBuffer;
    GLint _position;
    GLint _texcoord;
    GLint _ySampler;
    GLint _uSampler;
    GLint _vSampler;
    int64_t _lastFrameTime;
    size_t _lastDrawnWidth;
    size_t _lastDrawnHeight;
    CGSize _lastImageSize;
    CGSize _lastViewportSize;
    BOOL _mirroring;
    GLfloat _vertices[16];
    
}

#pragma mark - Object Lifecycle

+ (void)initialize {
    // Disable dithering for performance.
    glDisable(GL_DITHER);
}


- (instancetype)initWithContext:(EAGLContext*)context {
    NSAssert(context != nil, @"context cannot be nil");
    if (self = [super init]) {
        _context = context;
        _mirroring = NO;
    }
    return self;
}

- (void)updateVerticesWithViewportSize:(CGSize)viewportSize
                             imageSize:(CGSize)imageSize
{
    
    if (CGSizeEqualToSize(_lastImageSize, imageSize) &&
        CGSizeEqualToSize(_lastViewportSize, viewportSize)) {
        return;
    }
    
    _lastImageSize = imageSize;
    _lastViewportSize = viewportSize;
    
    float imageRatio =
    (float)imageSize.width / (float)imageSize.height;
    float viewportRatio =
    (float)viewportSize.width / (float)viewportSize.height;
    
    /*= {
     // X, Y, U, V.
     -1, -1, 0, 1,  // Bottom left.
     1,  -1, 1, 1,  // Bottom right.
     1,  1,  1, 0,  // Top right.
     -1, 1,  0, 0,  // Top left.
     };*/
    float scaleX = 1.0;
    float scaleY = 1.0;
    
    // Adjust position coordinates based on how the image will render to the
    // viewport. This logic tree implements a "scale to fill" semantic. You can
    // invert the logic if "scale to fit" works better for your needs.
    if (imageRatio < viewportRatio) {
        scaleY = viewportRatio / imageRatio;
    } else {
        scaleX = imageRatio / viewportRatio;
    }
    
    if (_mirroring) {
        scaleX *= -1;
    }
    
    _vertices[0] = -1 * scaleX;
    _vertices[1] = -1 * scaleY;
    _vertices[2] = 0;
    _vertices[3] = 1;
    _vertices[4] = 1 * scaleX;
    _vertices[5] = -1 * scaleY;
    _vertices[6] = 1;
    _vertices[7] = 1;
    _vertices[8] = 1 * scaleX;
    _vertices[9] = 1 * scaleY;
    _vertices[10] = 1;
    _vertices[11] = 0;
    _vertices[12] = -1 * scaleX;
    _vertices[13] = 1 * scaleY;
    _vertices[14] = 0;
    _vertices[15] = 0;
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(_vertices), _vertices,
                 GL_DYNAMIC_DRAW);
    
    // Read position attribute from |_vertices| with size of 2 and stride of 4
    // beginning at the start of the array. The last argument indicates offset
    // of data within |gVertices| as supplied to the vertex buffer.
    glVertexAttribPointer(_position, 2, GL_FLOAT, GL_FALSE, 4 * sizeof(GLfloat),
                          (void*)0);
    glEnableVertexAttribArray(_position);
    
    // Read texcoord attribute from |_vertices| with size of 2 and stride of 4
    // beginning at the first texcoord in the array. The last argument indicates
    // offset of data within |gVertices| as supplied to the vertex buffer.
    glVertexAttribPointer(_texcoord,
                          2,
                          GL_FLOAT,
                          GL_FALSE,
                          4 * sizeof(GLfloat),
                          (void*)(2 * sizeof(GLfloat)));
    glEnableVertexAttribArray(_texcoord);
    
}


- (BOOL)mirroring {
    return _mirroring;
}

- (void)setMirroring:(BOOL)mirroring {
    _mirroring = mirroring;
}

- (BOOL)clearFrame {
    if (!_isInitialized) {
        return NO;
    }
    [self ensureGLContext];
    glClear(GL_COLOR_BUFFER_BIT);
    return YES;
}

- (BOOL)drawFrame:(OTVideoFrame*)frame withViewport:(CGRect)viewport {
    if (!_isInitialized) {
        return NO;
    }
    if (_lastFrameTime == frame.timestamp.value) {
        return NO;
    }
    [self ensureGLContext];
    if (![self updateTextureSizesForFrame:frame] ||
        ![self updateTextureDataForFrame:frame]) {
        return NO;
    }
    glClear(GL_COLOR_BUFFER_BIT);
    CGSize imageSize = CGSizeMake(frame.format.imageWidth,
                                  frame.format.imageHeight);
    [self updateVerticesWithViewportSize:viewport.size
                               imageSize:imageSize];
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(_vertices), _vertices,
                 GL_DYNAMIC_DRAW);
    glDrawArrays(GL_TRIANGLE_FAN, 0, 4);
    _lastFrameTime = frame.timestamp.value;
    _lastDrawnWidth = frame.format.imageWidth;
    _lastDrawnHeight = frame.format.imageHeight;
    return YES;
}

- (void)setupGL {
    if (_isInitialized) {
        return;
    }
    [self ensureGLContext];
    if (![self setupProgram]) {
        return;
    }
    if (![self setupTextures]) {
        return;
    }
    if (![self setupVertices]) {
        return;
    }
    glUseProgram(_program);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glClearColor(0, 0, 0, 1);
    _isInitialized = YES;
}

- (void)teardownGL {
    if (!_isInitialized) {
        return;
    }
    [self ensureGLContext];
    glDeleteProgram(_program);
    _program = 0;
    glDeleteTextures(kNumTextures, _textures);
    glDeleteBuffers(1, &_vertexBuffer);
    _vertexBuffer = 0;
    _isInitialized = NO;
}

#pragma mark - Private

- (void)ensureGLContext {
    if ([EAGLContext currentContext] != _context) {
        NSAssert(_context, @"context shouldn't be nil");
        [EAGLContext setCurrentContext:_context];
    }
}

- (BOOL)setupProgram {
    NSAssert(!_program, @"program already set up");
    GLuint vertexShader = CreateShader(GL_VERTEX_SHADER, kVertexShaderSource);
    GLuint fragmentShader =
    CreateShader(GL_FRAGMENT_SHADER, kFragmentShaderSource);
    _program = CreateProgram(vertexShader, fragmentShader);
    // Shaders are created only to generate program.
    if (vertexShader) {
        glDeleteShader(vertexShader);
    }
    if (fragmentShader) {
        glDeleteShader(fragmentShader);
    }
    if (!_program) {
        return NO;
    }
    _position = glGetAttribLocation(_program, "position");
    _texcoord = glGetAttribLocation(_program, "texcoord");
    _ySampler = glGetUniformLocation(_program, "s_textureY");
    _uSampler = glGetUniformLocation(_program, "s_textureU");
    _vSampler = glGetUniformLocation(_program, "s_textureV");
    if (_position < 0 || _texcoord < 0 || _ySampler < 0 || _uSampler < 0 ||
        _vSampler < 0) {
        return NO;
    }
    return YES;
}

- (BOOL)setupTextures {
    glGenTextures(kNumTextures, _textures);
    // Set parameters for each of the textures we created.
    for (GLsizei i = 0; i < kNumTextures; i++) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, _textures[i]);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    return YES;
}

- (BOOL)updateTextureSizesForFrame:(OTVideoFrame*)frame {
    if (frame.format.imageHeight == _lastDrawnHeight &&
        frame.format.imageWidth == _lastDrawnWidth) {
        return YES;
    }
    GLsizei lumaWidth = frame.format.imageWidth;
    GLsizei lumaHeight = frame.format.imageHeight;
    GLsizei chromaWidth = frame.format.imageWidth / 2;
    GLsizei chromaHeight = frame.format.imageHeight / 2;
    for (GLint i = 0; i < kNumTextureSets; i++) {
        glActiveTexture(GL_TEXTURE0 + i * 3);
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     lumaWidth,
                     lumaHeight,
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     0);
        
        glActiveTexture(GL_TEXTURE0 + i * 3 + 1);
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     chromaWidth,
                     chromaHeight,
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     0);
        
        glActiveTexture(GL_TEXTURE0 + i * 3 + 2);
        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     chromaWidth,
                     chromaHeight,
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     0);
    }
    return YES;
}

- (BOOL)updateTextureDataForFrame:(OTVideoFrame*)frame {
    NSUInteger textureOffset = _currentTextureSet * 3;
    NSAssert(textureOffset + 3 <= kNumTextures, @"invalid offset");
    
    glActiveTexture(GL_TEXTURE0 + textureOffset);
    // When setting texture sampler uniforms, the texture index is used not
    // the texture handle.
    glUniform1i(_ySampler, textureOffset);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_LUMINANCE,
                 frame.format.imageWidth,
                 frame.format.imageHeight,
                 0,
                 GL_LUMINANCE,
                 GL_UNSIGNED_BYTE,
                 [frame.planes pointerAtIndex:0]);
    
    glActiveTexture(GL_TEXTURE0 + textureOffset + 1);
    glUniform1i(_uSampler, textureOffset + 1);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_LUMINANCE,
                 frame.format.imageWidth / 2,
                 frame.format.imageHeight / 2,
                 0,
                 GL_LUMINANCE,
                 GL_UNSIGNED_BYTE,
                 [frame.planes pointerAtIndex:1]);
    
    glActiveTexture(GL_TEXTURE0 + textureOffset + 2);
    glUniform1i(_vSampler, textureOffset + 2);
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_LUMINANCE,
                 frame.format.imageWidth / 2,
                 frame.format.imageHeight / 2,
                 0,
                 GL_LUMINANCE,
                 GL_UNSIGNED_BYTE,
                 [frame.planes pointerAtIndex:2]);
    
    _currentTextureSet = (_currentTextureSet + 1) % kNumTextureSets;
    return YES;
}

- (BOOL)setupVertices {
    NSAssert(!_vertexBuffer, @"vertex buffer already set up");
    glGenBuffers(1, &_vertexBuffer);
    if (!_vertexBuffer) {
        return NO;
    }
    
    // Populates vertex data which will be updated for frames and viewports
    // of differing size. We do this at least once so that the coordinate system
    // is already defined when the app resumes from the background.
    CGSize unitSize = CGSizeMake(1, 1);
    [self updateVerticesWithViewportSize:unitSize
                               imageSize:unitSize];
    
    return YES;
}


@end
