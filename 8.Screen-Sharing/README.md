Project 8: Screen Sharing
=========================

This project shows how to use OpenTok iOS SDK to publish a stream that uses a
UIView, instead of a camera, as the video source.

See the "Lets build OTPublisher" sample code for basic information on using a
custom video capturer.

The main storyboard includes a UITextView object that is referenced in the
ViewController.h file as the `timeDisplay` property. The `viewDidLoad` method
(in  ViewController.m) sets up a timer that updates this text field periodically
to display the NSDate timestamp. This example will use this text field's view as
the video source for the published stream.

_videoFrame = [[OTVideoFrame alloc] initWithFormat:format];


Upon connecting to the OpenTok session, the app instantiates an OTPublisherKit
object, and calls its `setCapturer()` method to set a custom video capturer.
This custom video capturer is defined by the TBScreenCapture class:

    - (void)doPublish
    {
        _publisher =
        [[OTPublisherKit alloc] initWithDelegate:self
                                            name:[UIDevice currentDevice].name
                                      audioTrack:NO
                                      videoTrack:YES];
    
        [_publisher setVideoType:OTPublisherKitVideoTypeScreen];
    
        TBScreenCapture* videoCapture =
        [[TBScreenCapture alloc] initWithView:self.view];
        [_publisher setVideoCapture:videoCapture];
    
        OTError *error = nil;
        [_session publish:_publisher error:&error];
        if (error) {
            [self showAlert:[error localizedDescription]];
        }
    }

Note that the call to the `[OTPublisher setPublisherVideoType]` method sets the
video type of the published stream to `OTPublisherKitVideoTypeScreen`. This
optimizes the video encoding for screen sharing. It is recommended to use a low
frame rate (5 frames per second or lower) with this video type. When using the
screen video type in a session that uses the [OpenTok Media
Router](https://tokbox.com/opentok/tutorials/create-session/#media-mode), the
audio-only fallback feature is disabled, so that the video does not drop out in
subscribers. (However, the publisher in this sample does not publish audio.)

The code instantiates a TBScreenCapture object and passes it into the
`[_publisher setVideoCapture:]` method. This sets the custom video capturer for
the publisher. The TBScreenCapture class implements the OTVideoCapture protocol,
defined in the OpenTok iOS SDK.

The implementation of the `[OTVideoCapture initCapture:]` method sets up a timer
that periodically gets a UIImage based on a screenshot of the main view
(`self.view`):

    __block UIImage* screen = [_self screenshot];
    [_self consumeFrame:[screen CGImage]];

The `[screenshot:]` method simply returns a UIImage representation of
`self.view`.

The `viewDidLoad:` method initialized a OTVideoFormat and OTVideoFrame object to
be used by the custom video capturer:

    OTVideoFormat *format = [[OTVideoFormat alloc] init];
    [format setPixelFormat:OTPixelFormatARGB];

The `consumeFrame:` method sets up properties of the current video frame:

    time_stamp = mach_absolute_time();
    time_stamp *= time_info.numer;
    time_stamp /= time_info.denom;

    CMTime time = CMTimeMake(time_stamp, 1000);
    CVImageBufferRef ref = [self pixelBufferFromCGImage:frame];

    CVPixelBufferLockBaseAddress(ref, 0);

    _videoFrame.timestamp = time;
    _videoFrame.format.estimatedFramesPerSecond =
    _minFrameDuration.timescale / _minFrameDuration.value;
    _videoFrame.format.estimatedCaptureDelay = 100;
    _videoFrame.orientation = OTVideoOrientationUp;
    
    [_videoFrame clearPlanes];
    [_videoFrame.planes addPointer:CVPixelBufferGetBaseAddress(ref)];

The `consumeFrame:` method then calls the
`[self.videoCaptureConsumer consumeFrame:_videoFrame]` method:

    [self.videoCaptureConsumer consumeFrame:_videoFrame];

The `videoCaptureConsumer` property of the OTVideoCapturer object is defined by
the OTVideoCaptureConsumer protocol. Its `consumeFrame:` method sets a video
frame to be published by the OTPublisherKit object.
