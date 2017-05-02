Project 7: Overlay Graphics
===========================

This project shows how to overlay graphics and UI controls onto publisher and 
subscriber views. It basically extends [project 2][1], "Let's build
OTPublisher." By the end of a code review, you should learn how to add
graphics on top of publisher and subscriber video views.

*Important:* To use this application, follow the instructions in the
[Quick Start](../README.md#quick-start) section of the main README file
for this repository.

Configuration Notes
===================

*   Since we are importing a number of classes implemented in project 2, the
    header search paths in the project build settings must be extended to look
    in the project 2 directory. Additionally, we must recompile the 
    implementation files in order to continue using the TBExamplePublisher,
    created in project 2. You will notice an extra group in this project's 
    navigator space with references to the files we need.
    

Application Notes
=================

*  This sample shows a toolbar in the publisher that contains a mute microphone
   button. When the user clicks the button, the app calls
   `[OTPublisherKit setPublishAudio:]`, passing in `YES` and `NO` to publish
   and mute audio in the publisher.

*  When the user clicks the toggle camera button on the publisher toolbar, the
   publisher switches between using the back and front cameras. Since this
   sample uses a custom video capturer (by extending the OTPublisherKit class),
   the code sets the `videoCapture.cameraPosition` property of the
   OTExamplePublisher instance to set the camera used by the publisher. In an
   app that uses the OTPublisher class to define the publisher, you can set the
   `cameraPosition` property of the OTPublisher instance.

*  The volume mute button on the subscriber view turns the subscriber's audio
   on and off. When the user clicks the button, the app calls
   `[OTSubscriberKit setSubscribeToAudio:]`, passing in `YES` and `NO` to
   subscribe to mute audio in the subscriber.

*  The application displays icons when a subscriber's video is disabled or
   is about to be disabled due to poor stream quality. This is available in
   sessions that have the media mode set to ["routed"][2]. This feature of
   the OpenTok Media Router has a subscriber drop the video stream when the
   video stream quality degrades. The icons are displayed in response to the
   `[OTSubscriberKitDelegate subscriberVideoDisabled:reason:]` and
   `[OTSubscriberKitDelegate subscriberVideoDisableWarning:]` messages. The
   icons are removed in response to the
   `[OTSubscriberKitDelegate subscriberVideoEnabled:reason:]` and
   `[OTSubscriberKitDelegate subscriberVideoDisableWarningLifted:]` messages.

*  The application displays an icon when an application is being archived. This
   is available in sessions that have the media mode set to ["routed"][2]. For
   more information, see the [Archiving Overview][3]. The icons are displayed
   and removed in response to the
   `[OTSesssionDelegate session:archiveStartedWithId:name:]` and
   `[OTSesssionDelegate session:archiveStoppedWithId:]` messages.
   Use one of the [OpenTok server SDKs][4] or the [OpenTok REST API][5] to start
   archiving the session.

*   Note that this sample application is not supported in the XCode iOS
    Simulator because the custom video capturer needs to acquire video from an
    iOS device camera.

[1]: ../2.Custom-Video-Driver
[2]: https://tokbox.com/opentok/tutorials/create-session/#media-mode
[3]: https://tokbox.com/opentok/tutorials/archiving/
[4]: https://tokbox.com/opentok/libraries/server/
[5]: https://tokbox.com/opentok/api/
