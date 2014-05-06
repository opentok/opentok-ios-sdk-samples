//
//  TBExampleVideoRender.h
//
//  Copyright (c) 2013 Tokbox, Inc. All rights reserved.
//

#import "TBExampleVideoRender.h"
#import <QuartzCore/CAEAGLLayer.h>
#import "ShaderUtilities.h"
#import "libyuv.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/ES2/glext.h>
#import <CoreVideo/CVOpenGLESTextureCache.h>


static const char *vertex_shader = "attribute vec4 position;\n\r\
attribute mediump vec4 textureCoordinate;\n\r\
varying mediump vec2 coordinate;\n\r\
void main()\n\r\
{\n\r\
gl_Position = position;\n\r\
coordinate = textureCoordinate.xy;\n\r\
}\n\r";

static const char *fragment_shader = "varying highp vec2 coordinate;\n\r\
uniform sampler2D videoframe;\n\r\
void main()\n\r\
{\n\r\
highp vec4 color = texture2D(videoframe, coordinate);\n\r\
gl_FragColor = color.bgra;\n\r\
}\n\r";

enum {
    ATTRIB_VERTEX,
    ATTRIB_TEXTUREPOSITON,
    NUM_ATTRIBUTES
};

/**
 * All instances of OTGLVideoRender will use a single shared EAGLContext. This
 * class manages that instance and helps ensure safe execution of OpenGL 
 * commands.
 */
@interface OTGLContext : NSObject {
	EAGLContext *sharedContext;
	EAGLSharegroup *_sharegroup;
	dispatch_queue_t contextQueue;
}
@property(readonly) EAGLContext *context;
@property(readonly) dispatch_queue_t contextQueue;
+ (void)useContext;
@end

@implementation OTGLContext

@synthesize context = sharedContext;
@synthesize contextQueue;

- (id)init
{
    self = [super init];
    if (self) {
        contextQueue = dispatch_queue_create("com.tokbox.shared_gl_context",
                                             NULL);
    }
    return self;
}

- (EAGLContext *)context
{
    if (sharedContext == nil)
    {
		sharedContext = [[EAGLContext alloc]
                         initWithAPI:kEAGLRenderingAPIOpenGLES2];
		if (!sharedContext) {
			return nil;
		}
        [EAGLContext setCurrentContext:sharedContext];
        
        glDisable(GL_DEPTH_TEST);
    }
    
    return sharedContext;
}

+ (OTGLContext *)sharedContext
{
    static dispatch_once_t pred;
    static OTGLContext *sharedContext = nil;
    
    dispatch_once(&pred, ^{
        sharedContext = [[[self class] alloc] init];
    });
    return sharedContext;
}

+ (dispatch_queue_t)contextQueue
{
    return [[self sharedContext] contextQueue];
}

+ (void) useContext
{
    EAGLContext *context = [[OTGLContext sharedContext] context];
    if ([EAGLContext currentContext] != context)
    {
        [EAGLContext setCurrentContext:context];
    }
}

@end


@implementation TBExampleVideoRender {
	int renderBufferWidth;
	int renderBufferHeight;
    
	CVOpenGLESTextureCacheRef videoTextureCache;
    
	GLuint frameBufferHandle;
	GLuint colorBufferHandle;
    GLuint passThroughProgram;
    
    void (^_snapshotBlock)(UIImage* snapshot);
    CGSize _videoFrameSize;
    CVPixelBufferRef pixelBufferRef;
    
	NSObject* _lock;
	
    BOOL _currentlyBackgrounded;
}

+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (const GLchar *)readFile:(NSString *)name
{
    NSString *path;
    const GLchar *source;
    
    path = [[NSBundle mainBundle] pathForResource:name ofType: nil];
    source = (GLchar *)[[NSString stringWithContentsOfFile:path
                                                  encoding:NSUTF8StringEncoding
                                                     error:nil] UTF8String];
    
    return source;
}

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self != nil) {
		// Use 2x scale factor on Retina displays.
		self.contentScaleFactor = [[UIScreen mainScreen] scale];
        
        // Initialize OpenGL ES 2
        CAEAGLLayer* eaglLayer = (CAEAGLLayer *)self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties =
        [NSDictionary dictionaryWithObjectsAndKeys:
         [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking,
         kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
         nil];
		
		if ( ![self initializeBuffers] ) {
			return nil;
		}
		_lock = [[NSObject alloc] init];
        _videoFrameSize = CGSizeZero;
        
        // Monitor application background/foreground activity to ensure safe
        // interaction with OpenGL APIs
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(enterBackgroundMode:)
         name:UIApplicationWillResignActiveNotification
         object:nil];
        
		[[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(leaveBackgroundMode:)
         name:UIApplicationDidBecomeActiveNotification
         object:nil];
        
        _currentlyBackgrounded =
        (UIApplicationStateActive !=
         [[UIApplication sharedApplication] applicationState]);

    }
	
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    // Reattach renderbuffer storage to match new size. Very carefully.
    if (frameBufferHandle && colorBufferHandle && _lock) {
        
        @synchronized(_lock) {
            
            dispatch_sync([OTGLContext sharedContext].contextQueue, ^{
                
                EAGLContext* oglContext = [OTGLContext sharedContext].context;
                
                [OTGLContext useContext];
                
                glBindFramebuffer(GL_FRAMEBUFFER, frameBufferHandle);
                glBindRenderbuffer(GL_RENDERBUFFER, colorBufferHandle);
                
                [oglContext renderbufferStorage:GL_RENDERBUFFER
                                   fromDrawable:nil];
                [oglContext renderbufferStorage:GL_RENDERBUFFER
                                   fromDrawable:(CAEAGLLayer *)self.layer];
                
                glGetRenderbufferParameteriv(GL_RENDERBUFFER,
                                             GL_RENDERBUFFER_WIDTH,
                                             &renderBufferWidth);
                glGetRenderbufferParameteriv(GL_RENDERBUFFER,
                                             GL_RENDERBUFFER_HEIGHT,
                                             &renderBufferHeight);
                
                glFramebufferRenderbuffer(GL_FRAMEBUFFER,
                                          GL_COLOR_ATTACHMENT0,
                                          GL_RENDERBUFFER,
                                          colorBufferHandle);
            });
        }
    }
}

- (void)enterBackgroundMode:(NSNotification*)notification
{
	@synchronized(_lock) {
		glFlush();
		_currentlyBackgrounded = YES;
	}
}

- (void)leaveBackgroundMode:(NSNotification*)notification
{
    _currentlyBackgrounded = NO;
}

- (BOOL)initializeBuffers
{
	BOOL success = YES;
	
	EAGLContext* oglContext = [OTGLContext sharedContext].context;
	
	glDisable(GL_DEPTH_TEST);
    
    glGenFramebuffers(1, &frameBufferHandle);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBufferHandle);
    
    glGenRenderbuffers(1, &colorBufferHandle);
    glBindRenderbuffer(GL_RENDERBUFFER, colorBufferHandle);
    
    [oglContext renderbufferStorage:GL_RENDERBUFFER
                       fromDrawable:(CAEAGLLayer *)self.layer];
    
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH,
                                 &renderBufferWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT,
                                 &renderBufferHeight);
    
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, colorBufferHandle);
    
    GLenum ret =glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if(ret != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"Failure with framebuffer generation");
		success = NO;
	}
    
    //  Create a new CVOpenGLESTexture cache
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL,
                                                oglContext, NULL,
                                                &videoTextureCache);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
        success = NO;
    }
    
    // attributes
    GLint attribLocation[NUM_ATTRIBUTES] = {
        ATTRIB_VERTEX, ATTRIB_TEXTUREPOSITON,
    };
    GLchar *attribName[NUM_ATTRIBUTES] = {
        "position", "textureCoordinate",
    };
    
    glueCreateProgram(vertex_shader, fragment_shader,
                      NUM_ATTRIBUTES,
                      (const GLchar **)&attribName[0],
                      attribLocation,
                      0, 0, 0,
                      &passThroughProgram);
    
    if (!passThroughProgram)
        success = NO;
    
    return success;
}

- (void)destroyBuffers {
    if (frameBufferHandle) {
        glDeleteFramebuffers(1, &frameBufferHandle);
        frameBufferHandle = 0;
    }
	
    if (colorBufferHandle) {
        glDeleteRenderbuffers(1, &colorBufferHandle);
        colorBufferHandle = 0;
    }
	
    if (passThroughProgram) {
        glDeleteProgram(passThroughProgram);
        passThroughProgram = 0;
    }
	
    if (videoTextureCache) {
        CFRelease(videoTextureCache);
        videoTextureCache = 0;
    }

}

- (void)renderWithSquareVertices:(const GLfloat*)squareVertices
                 textureVertices:(const GLfloat*)textureVertices
{
    // Use shader program.
	glUseProgram(passThroughProgram);
	
	// Update attribute values.
	glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices);
	glEnableVertexAttribArray(ATTRIB_VERTEX);
	glVertexAttribPointer(ATTRIB_TEXTUREPOSITON, 2, GL_FLOAT, 0, 0,
                          textureVertices);
	glEnableVertexAttribArray(ATTRIB_TEXTUREPOSITON);
	
	// Update uniform values if there are any
	
	// Validate program before drawing. This is a good check, but only really
    // necessary in a debug build.
	// DEBUG macro must be defined in your debug configurations if that's not
    // already the case.
#if defined(DEBUG)
	glueValidateProgram(passThroughProgram);
#endif
	
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	// Present
	glBindRenderbuffer(GL_RENDERBUFFER, colorBufferHandle);
	[[OTGLContext sharedContext].context presentRenderbuffer:GL_RENDERBUFFER];
}

- (CGRect)textureSamplingRectForCroppingTextureWithAspectRatio:
    (CGSize)textureAspectRatio toAspectRatio:(CGSize)croppingAspectRatio
{
	CGRect normalizedSamplingRect = CGRectZero;
	CGSize cropScaleAmount = CGSizeMake(croppingAspectRatio.width /
                                        textureAspectRatio.width,
                                        croppingAspectRatio.height /
                                        textureAspectRatio.height);
	CGFloat maxScale = fmax(cropScaleAmount.width, cropScaleAmount.height);
	CGSize scaledTextureSize = CGSizeMake(textureAspectRatio.width * maxScale,
                                          textureAspectRatio.height * maxScale);
	
	if ( cropScaleAmount.height > cropScaleAmount.width )
    {
		normalizedSamplingRect.size.width =
        croppingAspectRatio.width / scaledTextureSize.width;
		normalizedSamplingRect.size.height = 1.0;
	}
	else {
		normalizedSamplingRect.size.height =
        croppingAspectRatio.height / scaledTextureSize.height;
		normalizedSamplingRect.size.width = 1.0;
	}
	// Center crop
	normalizedSamplingRect.origin.x =
    (1.0 - normalizedSamplingRect.size.width)/2.0;
	normalizedSamplingRect.origin.y =
    (1.0 - normalizedSamplingRect.size.height)/2.0;
	
	return normalizedSamplingRect;
}

- (void)performSnapshot:(CVPixelBufferRef)pixelBuffer {
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGBitmapInfo bitmapInfo =
        kCGBitmapAlphaInfoMask & kCGImageAlphaNoneSkipLast;
    CGContextRef context =
    CGBitmapContextCreate(CVPixelBufferGetBaseAddress(pixelBuffer),
                          CVPixelBufferGetWidth(pixelBuffer),
                          CVPixelBufferGetHeight(pixelBuffer),
                          8,
                          CVPixelBufferGetBytesPerRow(pixelBuffer),
                          colorSpace,
                          bitmapInfo);
    
    CGColorSpaceRelease(colorSpace);
    
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    
    //orient things
    UIImage* snapshot = nil;
    const float scaleSize = 1.0;
    
    CGImageRef croppedImage =
    CGImageCreateWithImageInRect(cgImage,
                                 CGRectMake(0, 0,
                                            CGImageGetWidth(cgImage),
                                            CGImageGetWidth(cgImage)/1.333));
    
    snapshot = [[UIImage alloc] initWithCGImage:croppedImage
                                          scale:scaleSize
                                    orientation:UIImageOrientationUp];
    
    CGImageRelease(cgImage);
    CGImageRelease(croppedImage);
    CGContextRelease(context);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        _snapshotBlock(snapshot);
        _snapshotBlock = nil;
    });
}

- (CVPixelBufferRef)createPixelBufferWithFrame:(OTVideoFrame*)frame {
    size_t width = frame.format.imageWidth;
	size_t height = frame.format.imageHeight;
	if (_videoFrameSize.width != width || _videoFrameSize.height != height) {
		if(pixelBufferRef != NULL) {
			CFRelease(pixelBufferRef);
		}
		
		_videoFrameSize = CGSizeMake(width, height);
		
		NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:
								 [NSNumber numberWithBool:NO],
                                 kCVPixelBufferCGImageCompatibilityKey,
								 [NSNumber numberWithBool:NO],
                                 kCVPixelBufferCGBitmapContextCompatibilityKey,
                                 nil];
		
		CVReturn ret = CVPixelBufferCreate(kCFAllocatorDefault,
                                           width, height,
                                           kCVPixelFormatType_32BGRA,
                                           (CFDictionaryRef) options,
                                           &pixelBufferRef);
		
		[options release];
		
		NSParameterAssert(ret == kCVReturnSuccess && pixelBufferRef != NULL);
	}
    
	CVPixelBufferLockBaseAddress(pixelBufferRef, 0);
	uint8_t *pxdata = (uint8_t*)CVPixelBufferGetBaseAddress(pixelBufferRef);
    const uint8_t* yPlane = [frame.planes pointerAtIndex:0];
    const uint8_t* uPlane = [frame.planes pointerAtIndex:1];
    const uint8_t* vPlane = [frame.planes pointerAtIndex:2];

    int yStride = [[frame.format.bytesPerRow objectAtIndex:0] intValue];
    // multiply chroma strides by 2 as bytesPerRow represents 2x2 subsample
    int uStride = [[frame.format.bytesPerRow objectAtIndex:1] intValue] * 2;
    int vStride = [[frame.format.bytesPerRow objectAtIndex:2] intValue] * 2;

    // Use libyuv to convert to the RGB colorspace that OpenGL groks.
    I420ToARGB(yPlane, yStride,
               vPlane, uStride,
               uPlane, vStride,
               pxdata,
               frame.format.imageWidth * 4,
               frame.format.imageWidth, frame.format.imageHeight);

	CVPixelBufferUnlockBaseAddress(pixelBufferRef, 0);
    
    return pixelBufferRef;
	
}

- (void)renderVideoFrame:(OTVideoFrame*)frame
{

	@synchronized(_lock) {
		
		if (_currentlyBackgrounded) { return; }
		
        CVPixelBufferRef pixelBuffer = [self createPixelBufferWithFrame:frame];
        
		if (_snapshotBlock) {
            [self performSnapshot:pixelBuffer];
		}
		
		if (frameBufferHandle == 0) { return; }
		if (videoTextureCache == NULL) { return; }
		
		dispatch_sync([OTGLContext sharedContext].contextQueue, ^{
			
			[OTGLContext useContext];

        	// Create a CVOpenGLESTexture from the CVImageBuffer
			size_t frameWidth = CVPixelBufferGetWidth(pixelBuffer);
			size_t frameHeight = CVPixelBufferGetHeight(pixelBuffer);
			CVOpenGLESTextureRef texture = NULL;
			CVReturn err =
            CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                         videoTextureCache,
                                                         pixelBuffer,
                                                         NULL,
                                                         GL_TEXTURE_2D,
                                                         GL_RGBA,
                                                         frameWidth,
                                                         frameHeight,
                                                         GL_BGRA,
                                                         GL_UNSIGNED_BYTE,
                                                         0,
                                                         &texture);
			
			
			if (!texture || err) {
				NSLog(@"CVOpenGLESTextureCacheCreateTextureFromImage "
                      "failed error(%ul) width(%zul) height(%zul)", err,
                      frameWidth, frameHeight);
				return;
			}
			
			glBindTexture(CVOpenGLESTextureGetTarget(texture),
                          CVOpenGLESTextureGetName(texture));
			
			// Set texture parameters
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
			
			glBindFramebuffer(GL_FRAMEBUFFER, frameBufferHandle);
			
			// Set the view port to the entire view
			glViewport(0, 0, renderBufferWidth, renderBufferHeight);
			
			static const GLfloat squareVertices[] = {
				-1.0f, -1.0f,
				1.0f, -1.0f,
				-1.0f,  1.0f,
				1.0f,  1.0f,
			};
			
			// The texture vertices are set up such that we flip the texture
            //  vertically.
			// This is so that our top left origin buffers match OpenGL's bottom
            //  left texture coordinate system.
			CGRect textureSamplingRect =
            [self textureSamplingRectForCroppingTextureWithAspectRatio:
             CGSizeMake(frameWidth, frameHeight) toAspectRatio:
             self.bounds.size];
			GLfloat textureVertices[] =
            {
				CGRectGetMinX(textureSamplingRect),
                CGRectGetMaxY(textureSamplingRect),
				CGRectGetMaxX(textureSamplingRect),
                CGRectGetMaxY(textureSamplingRect),
				CGRectGetMinX(textureSamplingRect),
                CGRectGetMinY(textureSamplingRect),
				CGRectGetMaxX(textureSamplingRect),
                CGRectGetMinY(textureSamplingRect),
			};
			
			// Draw the texture on the screen with OpenGL ES 2
			[self renderWithSquareVertices:squareVertices
                           textureVertices:textureVertices];
			
			glBindTexture(CVOpenGLESTextureGetTarget(texture), 0);
			
			// Flush the CVOpenGLESTexture cache and release the texture
			CVOpenGLESTextureCacheFlush(videoTextureCache, 0);
			CFRelease(texture);
			
		});
	}
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_lock release];
    [self destroyBuffers];
    [super dealloc];
}

- (void)getSnapshotWithBlock:(void (^)(UIImage* snapshot))block {
    _snapshotBlock = [block copy];
}

@end
