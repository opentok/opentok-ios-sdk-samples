OpenTok iOS SDK Samples
=======================

This repository is meant to provide some examples for you to better understand
the features of the OpenTok iOS SDK. The sample applications are meant to be
used with the latest version of the
[OpenTok iOS SDK](https://tokbox.com/developer/sdks/ios/). Feel free to copy and
modify the source code herein for your own projects. Please consider sharing
your modifications with us, especially if they might benefit other developers
using the OpenTok iOS SDK. See the [License](LICENSE) for more information.

Quick Start
-----------

 1. Get values for your OpenTok **API key**, **session ID**, and **token**.
    See [Obtaining OpenTok Credentials](#obtaining-opentok-credentials)
    for important information.
 
 1. Install CocoaPods as described in [CocoaPods Getting Started](https://guides.cocoapods.org/using/getting-started.html#getting-started).
 
 1. In Terminal, `cd` to your project directory and type `pod install`.
 
 1. Reopen your project in Xcode using the new `Opentok-iOS-samples.xcworkspace` file.
 
 1. In the ViewController.swift file, replace the following empty strings
    with the corresponding API Key, session ID, and token values:
    
    ```objc
    // *** Fill the following variables using your own Project info  ***
    // ***          https://dashboard.tokbox.com/projects            ***
    // Replace with your OpenTok API key
    static NSString* const kApiKey = @"";
    // Replace with your generated session ID
    static NSString* const kSessionId = @"";
    // Replace with your generated token
    static NSString* const kToken = @"";
	```
    
 1. Use Xcode to build and run the app on an iOS simulator or device.

What's Inside
-------------

**Basics** - This basic application demonstrates a short path to 
getting started with the OpenTok iOS SDK.

**Custom Video Driver** - This project provides classes that implement
the OTVideoCapture and OTVideoRender interfaces of the core Publisher and
Subscriber classes. Using these modules, we can see the basic workflow of
sourcing video frames from the device camera in and out of OpenTok, via the
OTPublisherKit and OTSubscriberKit interfaces.

**Custom Audio Driver** - This project demonstrate how to use an external
audio source with the OpenTok SDK. This project utilizes CoreAudio and the
AUGraph API to create an audio session suitable for voice and video
communications.

**Screen Sharing** - This project demonstrates how to use a custom video
capturer to publish a stream that uses a UI view (instead of a camera) as
the video source.

**Live Photo Capture** - This project extends the video capture module 
implemented in project 2, and demonstrates how the AVFoundation media 
capture APIs can be used to simultaneously stream video and capture 
high-resolution photos from the same camera.

**Simple Multiparty** - This project demonstrates how to use the OpenTok iOS
SDK for a multi-party call. The application publishes audio/video from an
iOS device and can connect to multiple subscribers. However it shows only
one subscriber video at a time due to CPU limitations on iOS devices.

**Overlay Graphics** - This project shows how to overlay graphics for the following:

* A button for muting the publisher microphone

* A button for muting the subscriber audio

* Stream quality notification icons for the subscriber video

* Archive recording icons

This project barrows publisher and subscribers modules implemented in 
project 2.

**Audio Levels** - This project demonstrates how to use the OpenTok iOS SDK
for audio-only multi party calls. Both publisher and subscribers are
audio-based only. This application also shows how to use the audio level API
along with an audio meter UI for visualization of publisher and subscriber
audio levels.

**Ringtones** - This project extends on the work done in Project 3
(Custom Audio Driver) by extending the sample audio driver with an
AVAudioPlayer controller, which will play a short ringtone while waiting for
the subscriber to connect to the client device.

## Obtaining OpenTok Credentials

To use the OpenTok platform you need a session ID, token, and API Key.
You can get these values by creating a project on your [OpenTok Account
Page](https://tokbox.com/account/) and scrolling down to the Project Tools
section of your Project page. For production deployment, you must generate the
session ID and token values using one of the [OpenTok Server
SDKs](https://tokbox.com/developer/sdks/server/).
