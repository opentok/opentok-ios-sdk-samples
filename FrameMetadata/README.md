Custom Video Driver
==================================

This project uses the custom video driver features in the OpenTok iOS SDK.
By the end of a code review, you should have a basic understanding of the
internals of the video capture and render API.

Note that this sample application is not supported in the XCode iOS Simulator
because the custom video capturer needs to acquire video from an iOS device
camera.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.

TBExampleVideoRender and TBExampleVideoCapture
------------------------------------------

In this example we will create our implementations of `OTVideoRender` and
`OTVideoCapture` that will allow us to capture and render video by ourselves.

###TBExampleVideoRender

Both OTSubscriber and OTPublisher need an instance supporting the
`OTVideoRender` protocol to display video contents. In short, the instance
ID that is set to the `videoRender` property will receive YUV frames (I420) as
they are captured (publisher) or as they are received (subscriber). Note that,
although the publisher's `OTVideoCapture` interface can process multiple pixel
formats, the images passed through the rendering callback will always be in the
I420 YUV format.

TBExampleVideoRender is a copy of the default video renderer for the OpenTok
iOS SDK. It is borrowed and modified from a series of classes in Google's
[WebRTC][1] project.

In this example we wire a video renderer to the publisher's rendering
callback. An alternative approach for developers using video from the camera
with AVFoundation is to wire [AVCaptureVideoPreviewLayer][2] directly to the 
capture class and leave the `OTPublisherKit.videoRender` property nil.

To see TBExampleVideoRender in action, put a breakpoint on `renderVideoFrame:`.
You will see this method called for every video frame that is presented to the
rendering endpoint by the OpenTok iOS SDK.

###TBExampleVideoCapture

This class interfaces with AVFoundation to provide video capture support from
the device's camera hardware. By implementing the OTVideoCapture interface, it
can be used as a video capture endpoint OTPublisher to provide video for
publishing.

To see TBExampleVideoCapture in action, put a breakpoint on 
`captureOutput:didOutputSampleBuffer:fromConnection:`. This method is invoked by
AVFoundation for every frame that is output from the camera capture session.
After some processing, the video capture invokes its own 
`OTVideoCaptureConsumer` with the captured frame. Note the consumer is set by
the OpenTok iOS SDK during instantiation of the publisher.


Putting it all together
-----------------------

The [ViewController](Lets-Build-OTPublisher/ViewController.m) for this 
application is a near-identical clone of the previous, but providing the OTPublisher and
OTSubscriber with the our custom implementations for capturing and rendering.
Notice how a majority of the calls made into the OpenTok iOS SDK classes are declared
on the core classes, OTPublisherKit and OTSubscriberKit. Extending those core 
classes as is done in this example is as simple as defining a few simple
interfaces and plugging everything in at runtime. We hope that this new
class hierarchy will give you some ideas for how to extend the core 
functionality of the OpenTok iOS SDK to meet your application needs.


[1]: https://code.google.com/p/webrtc/source/browse/trunk/talk/app/webrtc/objc/
[2]: https://developer.apple.com/library/ios/documentation/AVFoundation/Reference/AVCaptureVideoPreviewLayer_Class/Reference/Reference.html
