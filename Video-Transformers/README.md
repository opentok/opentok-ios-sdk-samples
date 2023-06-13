Video Transformers
======================

The Video Transformers app is a very simple application created on top of Basic Video Chat meant to get a new developer
started using Media Processor APIs on OpenTok iOS SDK. For a full description, see the [Video Transformers tutorial at the
OpenTok developer center](https://tokbox.com/developer/guides/vonage-media-processor/ios).

You can use pre-built transformers in the Vonage Media Processor library or create your own custom video transformer to apply to published video.

You can use the OTPublisherKit.videoTransformers properties to apply video transformers to a stream.

For video, you can apply the background blur video transformer included in the Vonage Media Library.
You can use the <a href="/developer/sdks/ios/reference/Classes/OTPublisherKit.html#//api/name/audioTransformers"><code>OTPublisherKit.audioTransformers</code></a> and
<a href="/developer/sdks/ios/reference/Classes/OTPublisherKit.html#//api/name/videoTransformers"><code>OTPublisherKit.videoTransformers</code></a>
properties to apply audio and video transformers to a stream.

<p class="important">
  <b>Important:</b> The audio and video transformer API is a beta feature.
</p>

For video, you can apply the background blur video transformer included in the Vonage Media Library.

You can also create your own custom audio and video transformers.

## Applying a video transformer from the Vonage Media Library

Use the <a href="/developer/sdks/ios/reference/Classes/OTVideoTransformer.html#//api/name/initWithName:properties:"><code>[OTVideoTransformer initWithName:properties:]</code></a>
method to create a video transformer that uses a named transformer from the Vonage Media Library.

Currently, only one transformer is supported: background blur. Set the `name` parameter to `"BackgroundBlur"`.
Set the `properties` parameter to a JSON string defining properties for the transformer.
For the background blur transformer, this JSON includes one property -- `radius` -- which can be set
to `"High"`, `"Low"`, or `"None"`.

```objectivec
NSMutableArray * myVideoTransformers = [[NSMutableArray alloc] init];
OTVideoTransformer *backgroundBlur = [[OTVideoTransformer alloc] initWithName:@"BackgroundBlur"
                                                                   properties:@"{\"radius\":\"High\"}"];
[myVideoTransformers addObject:backgroundBlur];
_publisher.videoTransformers = [[NSArray alloc] initWithArray:myVideoTransformers];
```

## Creating a custom video transformer

Create a class that implements the <a href="/developer/sdks/ios/reference/Protocols/OTCustomVideoTransformer.html"><code>OTCustomVideoTransformer</code></a> 
protocol. Implement the `[OTCustomVideoTransformer transform:]` method, applying a transformation to the `OTVideoFrame` object passed into the method. The `[OTCustomVideoTransformer transform:]` method is triggered for each video frame:

```objectivec
@interface CustomTransformer : NSObject <OTCustomVideoTransformer>
@end
@implementation CustomTransformer
- (void)transform:(nonnull OTVideoFrame *)videoFrame {
    // Your custom transformation
}
@end
```

In this sample, to display one of the infinite transformations that can be applied to video frames, a logo is being added to the bottom right corner of the video.

```objectivec
@interface CustomTransformer : NSObject <OTCustomVideoTransformer>
@end
@implementation CustomTransformer
- (void)transform:(nonnull OTVideoFrame *)videoFrame {
    
    UIImage* image = [UIImage imageNamed:@"Vonage_Logo.png"];

    uint32_t videoWidth = videoFrame.format.imageWidth;
    uint32_t videoHeight = videoFrame.format.imageHeight;

    // Calculate the desired size of the image
    CGFloat desiredWidth = videoWidth / 8;  // Adjust this value as needed
    CGFloat desiredHeight = image.size.height * (desiredWidth / image.size.width);

    // Resize the image to the desired size
    UIImage *resizedImage = [self resizeImage:image toSize:CGSizeMake(desiredWidth, desiredHeight)];

    // Get pointer to the Y plane
    uint8_t* yPlane = [videoFrame getPlaneBinaryData:0];
    
    // Create a CGContext from the Y plane
    CGContextRef context = CGBitmapContextCreate(yPlane, videoWidth, videoHeight, 8, videoWidth, CGColorSpaceCreateDeviceGray(), kCGImageAlphaNone);
    
    // Location of the image (in this case right bottom corner)
    CGFloat x = videoWidth * 4/5;
    CGFloat y = videoHeight * 1/5;
    
    // Draw the resized image on top of the Y plane
    CGRect rect = CGRectMake(x, y, desiredWidth, desiredHeight);
    CGContextDrawImage(context, rect, resizedImage.CGImage);
    
    CGContextRelease(context);
}
@end
```

Then set the `OTPublisherKit.videoTransformers` property to an array that includes the object that implements the
OTCustomVideoTransformer interface:

```objectivec
CustomTransformer* logoTransformer;
logoTransformer = [customTransformer alloc];
OTVideoTransformer *myCustomTransformer = [[OTVideoTransformer alloc] initWithName:@"logo" transformer:logoTransformer];

NSMutableArray * myVideoTransformers = [[NSMutableArray alloc] init];
[myVideoTransformers addObject:myCustomTransformer];

_publisher.videoTransformers = [[NSArray alloc] initWithArray:myVideoTransformers];
```

You can combine the Vonage Media library transformer (see the previous section) with custom transformers or apply
multiple custom transformers by adding multiple PublisherKit.VideoTransformer objects to the ArrayList used
for the `OTPublisherKit.videoTransformers` property.

## Clearing video transformers for a publisher

To clear video transformers for a publisher, set the `OTPublisherKit.videoTransformers` property to an empty array.

```objectivec
_publisher.videoTransformers = [[NSArray alloc] init];
```
