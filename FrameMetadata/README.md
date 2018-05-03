Frame Metadata
==================================

This project shows how to set metadata (limited to 32 bytes) to a video frame, as well as how to read metadata from a video frame. It basically extends project 2, "Let's build OTPublisher." By the end of a code review, you should learn how to set and get your desired metedata from a video frame of publisher and subscriber.

Note that this sample application is not supported in the XCode iOS Simulator
because the custom video capturer needs to acquire video from an iOS device
camera.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.

TBExampleVideoRender and TBExampleVideoCapture
------------------------------------------

In this example we will include our implementations of OTVideoRender and OTVideoCapture that will allow us to capture and render video by ourselves.

The purpose of including a custom renderer and capturer is to access the underlying video frame (`OTVideoFrame`) which is not directly visible at `OTPublisher` or `OTSubscriber` class. Once each farme is ready to transmit to the OpenTok platform, we can now attach metadata by invoking the `[setMetadata:error:]` method. In the sample app, we show how to attach an ISO standard timestamp to a video frame:
```
- (void)finishPreparingFrame:(OTVideoFrame *)videoFrame {
    [self setTimestampToVideoFrame:videoFrame];
}

- (void)setTimestampToVideoFrame:(OTVideoFrame *)videoFrame {
    if (!videoFrame) {
        return;
    }
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    NSString *timestamp = [dateFormatter stringFromDate:[NSDate date]];
    
    NSData *metadata = [timestamp dataUsingEncoding:NSUTF8StringEncoding];
    OTError *error = nil;
    [videoFrame setMetadata:metadata error:&error];
    if (error) {
        NSLog(@"Append metadata error: %@", error);
    }
}
```
By conforming the `TBFrameCapturerMetadataDelegate` protocol and implementing the `[finishPreparingFrame:]` method, you will receive a ready video frame to attach your metadata.

To read the data, the approarch is similar. We simply need to access the underlying video frame and read the `metadata` property.
```
- (void)renderer:(TBExampleVideoRender*)renderer
 didReceiveFrame:(OTVideoFrame*)frame {
    if (renderer == _publisher.videoRender) {
        NSData *metadata = frame.metadata;
        NSString *timestamp = [[NSString alloc] initWithData:metadata encoding:NSUTF8StringEncoding];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.metadataLabel setText:timestamp];
            NSLog(@"Receiving publisher metadata: %@", timestamp);
        });
    }
    else if (renderer == _subscriber.videoRender) {
        NSLog(@"Receiving subscriber metadata");
    }
}
```
In the sample app, we conform `TBRendererDelegate` and implement `[renderer:didReceiveFrame:]` method to pass back each video frame.

*Note: you can always directly access a video frame from a custom captuere or renderer. We follow the classic delegate design pattern to enforce better abstraction and reusability.*
