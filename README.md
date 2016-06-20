OpenTok iOS SDK Samples
=======================

This repository is meant to provide some examples for you to better understand
the features of the OpenTok iOS SDK. The sample applications are meant to be
used with the latest version of the
[OpenTok iOS SDK](https://tokbox.com/developer/sdks/ios/). Feel free to copy and
modify the source code herein for your own projects. Please consider sharing
your modifications with us, especially if they might benefit other developers
using the OpenTok iOS SDK. See the [License](LICENSE) for more information.

What's Inside
-------------

Each of the projects build on the lessons of the previous. After reviewing
each, you will have an understanding of the OpenTok iOS SDK API. Additionally,
you will be able to get started with writing your own extensions to the default
capture implementations provided herein.

1.	**Hello World** - This basic application demonstrates a short path to 
	getting started with the OpenTok iOS SDK.

2.	**Let's Build OTPublisher** - This project provides classes that implement
	the OTVideoCapture and OTVideoRender interfaces of the core Publisher and
	Subscriber classes. Using these modules, we can see the basic workflow of
	sourcing video frames from the device camera in and out of OpenTok, via the
	OTPublisherKit and OTSubscriberKit interfaces.

3.	**Live Photo Capture** - This project extends the video capture module 
	implemented in project 2, and demonstrates how the AVFoundation media 
	capture APIs can be used to simultaneously stream video and capture 
	high-resolution photos from the same camera.

4.	**Overlay Graphics** - This project shows how to overlay graphics for the following:

    * A button for muting the publisher microphone

    * A button for muting the subscriber audio

    * Stream quality notification icons for the subscriber video

    * Archive recording icons

	This project barrows publisher and subscribers modules implemented in 
	project 2.
	
5.	**Multi-Party Call** - This project demonstrates how to use the OpenTok iOS
    SDK for a multi-party call. The application publishes audio/video from an
    iOS device and can connect to multiple subscribers. However it shows only
    one subscriber video at a time due to CPU limitations on iOS devices.

6.	**Audio Levels** - This project demonstrates how to use the OpenTok iOS SDK
    for audio-only multi party calls. Both publisher and subscribers are
    audio-based only. This application also shows how to use the audio level API
    along with an audio meter UI for visualization of publisher and subscriber
    audio levels.

7.	**External Audio Device** - This project demonstrate how to use an external
    audio source with the OpenTok SDK. This project utilizes CoreAudio and the
    AUGraph API to create an audio session suitable for voice and video
    communications.

8.	**Screen-Sharing** - This project demonstrates how to use a custom video
    capturer to publish a stream that uses a UI view (instead of a camera) as
    the video source.

9.  **Default-Camera-Capturer** - This project demonstrates how to set resolution 
    and framerate when using the default camera capturer. (i.e we set in Publisher
    Constructor)

Referencing OpenTok.framework
-----------------------------

Each project includes a symlink to `OpenTok.framework`, up one directory level
from the root of this repository. If you are reading this from a distribution
tarball of the OpenTok iOS SDK, then these links should work fine. If you have
[cloned][opentok-ios-samples] this repository
directly, you will have to update the links to point to your copy of
`OpenTok.framework`, available at
https://tokbox.com/opentok/libraries/client/ios/.

Getting Sample Code Updates
---------------------------

This README and the sample applications are maintained separately from
releases of the [OpenTok iOS SDK][opentok-ios-sdk]. A snapshot of this 
repository is included in the distribution of the SDK. To get the latest
updates to these example applications and accompanying documentation, be sure
to clone the sample repository itself:
https://github.com/opentok/opentok-ios-sdk-samples/

[opentok-ios-samples]: https://github.com/opentok/opentok-ios-sdk-samples/
[opentok-ios-sdk]: http://tokbox.com/opentok/libraries/client/ios 
