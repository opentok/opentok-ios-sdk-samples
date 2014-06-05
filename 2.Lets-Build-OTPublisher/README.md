Project 2: Let's Build OTPublisher
==================================

This project attempts to explain the new video handling features in version 2.2
of the OpenTok iOS SDK. By the end of a code review, you should have a basic
understanding of the internals of the video capture and render API, as well as
how to start building your own extensions to the core publisher and subscriber
classes.


TBExamplePublisher and TBExampleSubscriber
------------------------------------------

For our example, we create the alterna-universe classes TBExamplePublisher and 
TBExampleSubscriber. Like the OT-prefixed similar classes, these are subclasses of the
core OTPublisherKit and OTSubscriberKit, and will provide implementations for
the video capture and render interfaces, where needed.

TBExamplePublisher will bind the device's camera to the core publisher class, 
OTPublisherKit. The enabling mechanisms behind the scenes are a driver to
interface with AVFoundation (to manage the camera and provide video), and the
OTVideoCapture interface, which allows us to source arbitrary video data into
the OTPublisherKit runtime.

###TBExampleVideoRender
Both TBExampleSubscriber and TBExamplePublisher will use a generic video 
renderer, borrowed and modified from Apple's [Rosy Writer][1]
sample application. A talented OpenGL developer could probably make improvements
to this implementation, but it will work for the purposes of this demo. Both 
classes need to provide an implementation of the OTVideoRender interface, each
for a different reason. TBExamplePublisher provides this render endpoint simply
to demonstrate an alternative approach from using AVFoundation's
[AVCaptureVideoPreviewLayer][2]
class. Both approaches have merit, but we chose this just to show that both the
OTPublisherKit and OTSubscriberKit rendering endpoints behave in the same way.

To see TBExampleVideoRender in action, put a breakpoint on `renderVideoFrame:`.
You will see this method fire for every video frame that is presented to the
rendering endpoint by the OpenTok SDK.

###TBExampleVideoCapture
This class interfaces with AVFoundation to provide video capture support from
the device's camera hardware. By implementing the OTVideoCapture interface, it
can be used as a video capture endpoint TBExamplePublisher to provide video for 
publishing.

To see TBExampleVideoCapture in action, put a breakpoint on 
`captureOutput:didOutputSampleBuffer:fromConnection:`. This method is invoked by
AVFoundation for every frame that is output from the camera capture session.
After some processing, the video capture invokes its own 
`OTVideoCaptureConsumer` with the captured frame. Note the consumer is set by
the OpenTok SDK during instantiation of the publisher.


Putting it all together
=======================

The [ViewController](Lets-Build-OTPublisher/ViewController.m) for this 
application is a near-identical clone of the previous, with text substitutions
for our newly-minted example publisher and subscriber classes. Notice how a 
majority of the calls we are making into the OpenTok SDK classes is declared on
the core classes, OTPublisherKit and OTSubscriberKit. Extending those core 
classes as we have done in this example is as simple as defining a few simple
interfaces, and plugging everything in at runtime. We hope that this new
class hierarchy will give you some ideas for how to extend the core 
functionality of the OpenTok SDK to meet your application needs.


[1]: https://developer.apple.com/library/IOS/samplecode/RosyWriter/Introduction/Intro.html
[2]: https://developer.apple.com/library/ios/documentation/AVFoundation/Reference/AVCaptureVideoPreviewLayer_Class/Reference/Reference.html
